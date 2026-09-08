#!/usr/bin/env python3
"""Release the calling shell before inspecting or reconciling its Herdr pane."""
from __future__ import annotations

import json
import os
from pathlib import Path
import sys
import tempfile
import traceback

import team


def state_directory():
    return Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "fedora-niri-dotfiles/herdr/runs"


def status(directory):
    try:
        name = (directory / "latest").read_text().strip()
        if not name.startswith("run-") or Path(name).name != name:
            raise ValueError("invalid run reference")
        run = directory / name
        result = json.loads((run / "result.json").read_text())
        print((run / "output.log").read_text(), end="")
        if result["state"] == "running":
            print("Controller running; rerun --status for the final result.")
            return 2
        print(f"Controller finished with exit status {result['exit_code']}.")
        return result["exit_code"]
    except (OSError, ValueError, KeyError) as exc:
        print(f"error: cannot read controller status: {exc}", file=sys.stderr)
        return 1


def launch():
    if sys.argv[1:] == ["--status"]:
        return status(state_directory())
    args = team.parse_arguments()
    if args.validate_config:
        return team.main()

    # Syntax/configuration failures remain synchronous; live checks belong to
    # the detached worker so neither it nor its CLI children occupy the pane.
    team.load_manifest(team.repo_root())
    os.umask(0o077)
    directory = state_directory()
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="run-", dir=directory))
    output = (run / "output.log").open("w", buffering=1)
    result = run / "result.json"
    result.write_text(json.dumps({"state": "running"}))
    fd, temporary = tempfile.mkstemp(prefix=".latest-", dir=directory)
    with os.fdopen(fd, "w") as handle:
        handle.write(run.name + "\n")
    os.replace(temporary, directory / "latest")

    # The pipe gates work on launcher exit, not an arbitrary startup sleep.
    # Herdr polling then accounts for the shell regaining terminal ownership.
    read_fd, write_fd = os.pipe()
    sys.stdout.flush()
    sys.stderr.flush()
    pid = os.fork()
    if pid:
        os.close(read_fd)
        output.close()
        print(f"Started Herdr controller (PID {pid}). This is not a success result.")
        print(f"Log: {run / 'output.log'}")
        print("Run herdr/bootstrap-team.sh --status to read the result.")
        # write_fd closes at process exit, after the launch message is flushed.
        return 0

    exit_code = 1
    try:
        os.close(write_fd)
        os.setsid()
        with open(os.devnull, "rb") as null:
            os.dup2(null.fileno(), 0)
        os.dup2(output.fileno(), 1)
        os.dup2(output.fileno(), 2)
        sys.stdout.reconfigure(line_buffering=True)
        sys.stderr.reconfigure(line_buffering=True)
        os.read(read_fd, 1)
        os.close(read_fd)
        exit_code = team.main()
    except BaseException:
        traceback.print_exc()
    finally:
        sys.stdout.flush()
        sys.stderr.flush()
        temporary = run / ".result.json"
        temporary.write_text(json.dumps({"state": "finished", "exit_code": exit_code}) + "\n")
        os.replace(temporary, result)
        os._exit(exit_code)


if __name__ == "__main__":
    try:
        raise SystemExit(launch())
    except (OSError, team.WorkflowError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
