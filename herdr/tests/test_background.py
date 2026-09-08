#!/usr/bin/env python3
"""Exercise the public launcher with a real shell/PTY and a fake Herdr API."""
from __future__ import annotations

import fcntl
import json
import os
from pathlib import Path
import pty
import select
import subprocess
import time
import unittest
from unittest.mock import patch

from test_team import Harness, MODULE, ROOT, pristine


class BackgroundLaunch(unittest.TestCase):
    CONTROLLER_TIMEOUT = 60

    def setUp(self):
        self.h = Harness(pristine())
        self.runs = self.h.path / "state/fedora-niri-dotfiles/herdr/runs"
        # Wrap the existing fake, deriving occupancy from the actual PTY's
        # foreground group instead of declaring every shell empty by fiat.
        fake = self.h.bin / "herdr"
        fake.unlink()
        fake.write_text('''#!/usr/bin/env python3
import json, os, runpy, sys, time
from pathlib import Path
path = Path(os.environ["FAKE_HERDR_STATE"])
state = json.loads(path.read_text())
if sys.argv[1:] == ["--version"]: time.sleep(state.get("version_delay", 0))
shell_stat = Path(f"/proc/{state['shell_pid']}/stat").read_text().rsplit(")", 1)[1].split()
group = int(shell_stat[5])
processes = []
for entry in Path("/proc").iterdir():
    if not entry.name.isdigit(): continue
    try:
        fields = (entry / "stat").read_text().rsplit(")", 1)[1].split()
        if int(fields[2]) == group and int(entry.name) != state["shell_pid"]:
            processes.append({"pid": int(entry.name), "name": "foreground job"})
    except (OSError, ValueError): pass
state["processes"]["opaque-pane-1"] = processes
state["worker_detached"] = os.getsid(os.getppid()) != os.getsid(state["shell_pid"])
state["worker_stdin"] = os.readlink(f"/proc/{os.getppid()}/fd/0")
state["worker_stdout"] = os.readlink(f"/proc/{os.getppid()}/fd/1")
if "start" in sys.argv and "opaque-pane-1" in sys.argv and processes:
    state["unsafe_start"] = True
path.write_text(json.dumps(state))
runpy.run_path(os.environ["FAKE_HERDR_IMPLEMENTATION"], run_name="__main__")
''')
        fake.chmod(0o700)
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            env = os.environ.copy()
            env.update({"PATH": f"{self.h.bin}:/usr/bin:/bin", "FAKE_HERDR_STATE": str(self.h.state_path),
                        "FAKE_HERDR_IMPLEMENTATION": str(ROOT / "herdr/tests/fake-herdr.py"),
                        "XDG_STATE_HOME": str(self.h.path / "state"),
                        "HERDR_ENV": "1", "HERDR_SOCKET_PATH": "/tmp/fake-session/herdr.sock",
                        "HERDR_PANE_ID": "opaque-pane-1", "HERDR_TAB_ID": "opaque-tab-1",
                        "HERDR_WORKSPACE_ID": "opaque-workspace-1", "PS1": "TEST_READY> "})
            os.chdir(ROOT)
            os.execve("/usr/bin/zsh", ["zsh", "-f", "-i"], env)
        state = self.h.state()
        state["shell_pid"] = self.pid
        self.h.state_path.write_text(json.dumps(state))
        self.read_until("TEST_READY> ")

    def tearDown(self):
        # Only the temporary PTY shell and detached test workers are ours.
        for result in self.runs.glob("run-*/result.json"):
            if json.loads(result.read_text())["state"] == "running":
                self.wait_result(result.parent)
        os.write(self.fd, b"exit\n")
        os.waitpid(self.pid, 0)
        os.close(self.fd)

    def read_until(self, marker, timeout=10):
        output = b""
        deadline = time.monotonic() + timeout
        while marker.encode() not in output and time.monotonic() < deadline:
            if select.select([self.fd], [], [], .1)[0]:
                output += os.read(self.fd, 65536)
        self.assertIn(marker, output.decode(errors="replace"))
        return output.decode(errors="replace")

    def launch(self, mode, suffix=""):
        os.write(self.fd, f"herdr/bootstrap-team.sh {mode} --settle-seconds 0.5{suffix}\n".encode())
        output = self.read_until("TEST_READY> ")
        self.assertIn("Started Herdr controller", output)
        return self.runs / (self.runs / "latest").read_text().strip(), output

    def wait_result(self, run):
        deadline = time.monotonic() + self.CONTROLLER_TIMEOUT
        while time.monotonic() < deadline:
            result = json.loads((run / "result.json").read_text())
            if result["state"] == "finished":
                return result["exit_code"], (run / "output.log").read_text()
            time.sleep(.05)
        self.fail(f"controller did not finish: {run}")

    def test_foreground_script_is_busy_but_public_launcher_releases_shell(self):
        # Reproduce the original failure without changing the live session.
        os.write(self.fd, b"python3 herdr/team.py --dry-run --settle-seconds 0\n")
        self.assertIn("not an idle shell", self.read_until("TEST_READY> "))
        for mode in ("--dry-run", "--setup", "--repair", "--check"):
            run, _ = self.launch(mode)
            code, log = self.wait_result(run)
            self.assertEqual(code, 0, log)
            state = self.h.state()
            self.assertTrue(state["worker_detached"])
            self.assertEqual(state["worker_stdin"], "/dev/null")
            self.assertEqual(state["worker_stdout"], str(run / "output.log"))
            self.assertFalse(state.get("unsafe_start"))
            if mode == "--dry-run": self.assertEqual(state["mutations"], [])
            self.assertEqual((run / "output.log").stat().st_mode & 0o777, 0o600)
        self.assertEqual(len(self.h.state()["agents"]), 6)

    def test_occupied_caller_still_fails_without_mutations(self):
        # Keep the shell's foreground job alive after the launcher exits.
        run, _ = self.launch("--setup", "; sleep 2")
        code, log = self.wait_result(run)
        self.assertEqual(code, 1, log)
        self.assertIn("not an idle shell", log)
        self.assertEqual(self.h.state()["mutations"], [])

    def test_redirected_launch_and_running_status(self):
        state = self.h.state()
        state["version_delay"] = 1
        self.h.state_path.write_text(json.dumps(state))
        launch_log = self.h.path / "launch.log"
        os.write(self.fd, f"herdr/bootstrap-team.sh --dry-run > {launch_log} 2>&1\n".encode())
        self.read_until("TEST_READY> ")
        self.assertIn("Started Herdr controller", launch_log.read_text())
        run = self.runs / (self.runs / "latest").read_text().strip()
        os.write(self.fd, b"herdr/bootstrap-team.sh --status; echo STATUS_CODE=$?\n")
        self.assertIn("STATUS_CODE=2", self.read_until("TEST_READY> "))
        code, log = self.wait_result(run)
        self.assertEqual(code, 0, log)
        calls = self.h.state()["calls"]
        os.write(self.fd, b"herdr/bootstrap-team.sh --status; echo STATUS_CODE=$?\n")
        self.assertIn("STATUS_CODE=0", self.read_until("TEST_READY> "))
        self.assertEqual(self.h.state()["calls"], calls)
        self.assertEqual(self.h.state()["mutations"], [])

    def test_concurrent_controller_fails_and_status_is_read_only(self):
        lock = self.h.path / "state/fedora-niri-dotfiles/herdr/reconcile.lock"
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open("w") as handle:
            fcntl.flock(handle, fcntl.LOCK_EX)
            run, _ = self.launch("--repair")
            code, log = self.wait_result(run)
        self.assertEqual(code, 1, log)
        self.assertIn("another Herdr controller is running", log)
        self.assertEqual(self.h.state()["mutations"], [])
        calls = self.h.state()["calls"]
        os.write(self.fd, b"herdr/bootstrap-team.sh --status; echo STATUS_CODE=$?\n")
        output = self.read_until("TEST_READY> ")
        self.assertIn("STATUS_CODE=1", output)
        self.assertEqual(self.h.state()["calls"], calls)


class TransitionSafety(unittest.TestCase):
    def test_synchronous_modes_do_not_spawn_workers(self):
        h = Harness(pristine())
        env = {**os.environ, "XDG_STATE_HOME": str(h.path / "state")}
        for args, expected in ((["--help"], 0), (["--validate-config"], 0), (["--invalid"], 2)):
            result = subprocess.run([str(ROOT / "herdr/bootstrap-team.sh"), *args], env=env,
                                    text=True, capture_output=True)
            self.assertEqual(result.returncode, expected, result.stderr)
        self.assertFalse((h.path / "state").exists())

    def test_busy_pane_after_planning_is_not_started(self):
        root = ROOT
        manifest = MODULE.load_manifest(root)
        pane = {"pane_id": "pane", "tab_id": "tab", "cwd": str(root)}
        snap = MODULE.Snapshot([], {"workspace_id": "workspace"}, [], [pane], [], {"pane": [{"name": "vim"}]})
        from unittest.mock import Mock
        api = Mock()
        with patch.object(MODULE, "discover", return_value=snap):
            with self.assertRaisesRegex(MODULE.WorkflowError, "no longer an empty shell"):
                MODULE.apply_plan(api, manifest, root, [MODULE.Operation("start", tab="Build", role="coordinator", target="pane")], {})
        api.mutate.assert_not_called()


if __name__ == "__main__":
    unittest.main()
