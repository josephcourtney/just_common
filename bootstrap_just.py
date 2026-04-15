#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from pathlib import Path


REMOTE_NAME = "just_common"
REMOTE_URL = "git@github.com:josephcourtney/just_common.git"
REMOTE_REF = "main"
PREFIX = "tools/just"
COMMON_PATH = f"{PREFIX}/common.just"
BOOTSTRAP_PATH_IN_REMOTE = "bootstrap_just.py"

JUSTFILE_TEXT = """set shell := ["bash", "-euo", "pipefail", "-c"]
set dotenv-load := true

ROOT_DIR := justfile_directory()
PKG_DIR := ROOT_DIR + "/packages"

import "tools/just/common.just"
"""


def run(*args: str, check: bool = True, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        list(args),
        text=True,
        capture_output=capture,
        check=check,
    )


def repo_root() -> Path:
    cp = run("git", "rev-parse", "--show-toplevel", capture=True)
    return Path(cp.stdout.strip())


def git_dir() -> Path:
    cp = run("git", "rev-parse", "--git-dir", capture=True)
    return (
        (repo_root() / cp.stdout.strip()).resolve() if cp.stdout.strip() != ".git" else (repo_root() / ".git")
    )


def ensure_git_repo() -> None:
    try:
        run("git", "rev-parse", "--is-inside-work-tree", capture=True)
    except subprocess.CalledProcessError:
        raise SystemExit("ERROR: not inside a git repository")


def ensure_clean_worktree() -> None:
    cp = run("git", "status", "--porcelain", capture=True)
    if cp.stdout.strip():
        raise SystemExit("ERROR: working tree is not clean")


def ensure_subtree_available() -> None:
    cp = run("git", "subtree", "-h", check=False, capture=True)
    text = (cp.stdout or "") + (cp.stderr or "")
    if "usage: git subtree " not in text:
        raise SystemExit("ERROR: git subtree is required but unavailable")


def ensure_remote() -> None:
    cp = run("git", "remote", "get-url", REMOTE_NAME, check=False, capture=True)
    current = cp.stdout.strip() if cp.returncode == 0 else ""
    if not current:
        run("git", "remote", "add", REMOTE_NAME, REMOTE_URL)
    elif current != REMOTE_URL:
        run("git", "remote", "set-url", REMOTE_NAME, REMOTE_URL)


def fetch_remote() -> None:
    run("git", "fetch", REMOTE_NAME, REMOTE_REF)


def remote_blob(revpath: str) -> bytes:
    cp = run("git", "show", revpath, capture=True)
    return cp.stdout.encode()


def remote_commit() -> str:
    cp = run("git", "rev-parse", f"{REMOTE_NAME}/{REMOTE_REF}", capture=True)
    return cp.stdout.strip()


def write_file(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as tmp:
        tmp.write(content)
        tmp_path = Path(tmp.name)
    tmp_path.replace(path)


def write_text(path: Path, text: str) -> None:
    write_file(path, text.encode())


def ensure_justfile(root: Path, rewrite: bool = False) -> None:
    path = root / "justfile"
    if path.exists() and not rewrite:
        return
    write_text(path, JUSTFILE_TEXT)


def self_update() -> None:
    ensure_remote()
    fetch_remote()

    root = repo_root()
    local = root / "bootstrap_just.py"
    remote = remote_blob(f"{REMOTE_NAME}/{REMOTE_REF}:{BOOTSTRAP_PATH_IN_REMOTE}")

    local_bytes = local.read_bytes() if local.exists() else b""
    if local_bytes == remote:
        return

    print("[bootstrap] updating bootstrap_just.py")
    write_file(local, remote)
    os.execv(sys.executable, [sys.executable, str(local), *sys.argv[1:]])


def init(rewrite_justfile: bool) -> None:
    ensure_git_repo()
    ensure_clean_worktree()
    ensure_subtree_available()
    ensure_remote()
    fetch_remote()

    root = repo_root()
    ensure_justfile(root, rewrite=rewrite_justfile)

    if (root / COMMON_PATH).exists():
        print("Shared just tooling already exists.")
        return

    run("git", "subtree", "add", f"--prefix={PREFIX}", REMOTE_NAME, REMOTE_REF, "--squash")


def update() -> None:
    ensure_git_repo()
    ensure_clean_worktree()
    ensure_subtree_available()
    ensure_remote()
    fetch_remote()
    run("git", "subtree", "pull", f"--prefix={PREFIX}", REMOTE_NAME, REMOTE_REF, "--squash")


def sync_if_needed() -> None:
    ensure_git_repo()
    ensure_subtree_available()
    ensure_remote()
    fetch_remote()

    root = repo_root()
    common = root / COMMON_PATH
    if not common.exists():
        init(rewrite_justfile=False)
        return

    current = remote_commit()
    stamp = git_dir() / "just-common-sync.sha"
    previous = stamp.read_text().strip() if stamp.exists() else ""

    if previous == current:
        return

    ensure_clean_worktree()
    print(f"[bootstrap] syncing shared tooling to {current}")
    run("git", "subtree", "pull", f"--prefix={PREFIX}", REMOTE_NAME, REMOTE_REF, "--squash")
    write_text(stamp, current + "\n")


def run_just(args: list[str]) -> int:
    sync_if_needed()
    cp = subprocess.run(["just", *args], text=True)
    return cp.returncode


def main() -> None:
    ensure_git_repo()
    self_update()

    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_init = sub.add_parser("init")
    p_init.add_argument("--rewrite-justfile", action="store_true")

    sub.add_parser("update")

    p_run = sub.add_parser("run")
    p_run.add_argument("just_args", nargs=argparse.REMAINDER)

    args = parser.parse_args()

    if args.cmd == "init":
        init(rewrite_justfile=args.rewrite_justfile)
    elif args.cmd == "update":
        update()
    elif args.cmd == "run":
        raise SystemExit(run_just(args.just_args))


if __name__ == "__main__":
    main()
