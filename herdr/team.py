#!/usr/bin/env python3
"""Validate and additively reconcile the persistent dotfiles Herdr team."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tomllib

ROLE_RE = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")
SUPPORTED_HERDR = (0, 8, 2)


class WorkflowError(RuntimeError):
    pass


class Herdr:
    def __init__(self, binary: str, session: str, dry_run: bool = False):
        self.binary = binary
        self.session = session
        self.dry_run = dry_run

    def command(self, *args: str) -> list[str]:
        return [self.binary, "--session", self.session, *args]

    def json(self, *args: str) -> dict:
        proc = subprocess.run(
            self.command(*args), text=True, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, check=False, timeout=30,
        )
        if proc.returncode != 0:
            detail = proc.stderr.strip()[:1000] or proc.stdout.strip()[:1000]
            raise WorkflowError(f"Herdr command failed ({proc.returncode}): {detail}")
        try:
            value = json.loads(proc.stdout)
        except json.JSONDecodeError as exc:
            raise WorkflowError("Herdr returned malformed JSON") from exc
        if not isinstance(value, dict) or not isinstance(value.get("result"), dict):
            raise WorkflowError("Herdr JSON response is missing result")
        return value["result"]

    def mutate(self, *args: str) -> dict:
        print("+", " ".join(self.command(*args)))
        if self.dry_run:
            return {}
        return self.json(*args)


def trusted_executable(name: str) -> str:
    candidate = shutil.which(name)
    if not candidate:
        raise WorkflowError(f"{name} is not installed")
    path = Path(candidate).resolve()
    details = path.stat()
    if not stat.S_ISREG(details.st_mode):
        raise WorkflowError(f"{name} is not a regular file")
    system_binary = path.is_relative_to("/usr/bin") or path.is_relative_to("/usr/local/bin")
    if (details.st_uid not in {0, os.getuid()} and not system_binary) or details.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise WorkflowError(f"{name} executable has unsafe ownership or permissions")
    return str(path)


def repo_root() -> Path:
    root = Path(__file__).resolve().parent.parent
    proc = subprocess.run(
        [trusted_executable("git"), "-C", str(root), "rev-parse", "--show-toplevel"],
        text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False,
    )
    if proc.returncode != 0 or Path(proc.stdout.strip()).resolve() != root:
        raise WorkflowError("team.py is not inside the canonical dotfiles checkout")
    if not (root / "AGENTS.md").is_file():
        raise WorkflowError("canonical checkout is missing AGENTS.md")
    return root


def load_manifest(root: Path) -> dict:
    path = root / "herdr" / "team.toml"
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    required = {"schema_version", "workflow_version", "session", "workspace", "agent_kind", "max_agents_per_tab", "tabs", "prompts"}
    if set(data) != required or data["schema_version"] != 1:
        raise WorkflowError("team.toml has an unsupported schema")
    if data["session"] == "default" or not ROLE_RE.fullmatch(data["session"]):
        raise WorkflowError("team.toml has an unsafe session name")
    if data["agent_kind"] != "codex" or data["max_agents_per_tab"] > 4:
        raise WorkflowError("team.toml violates the supported agent policy")
    if len(data["tabs"]) != 2:
        raise WorkflowError("team.toml must declare exactly two tabs")
    roles: list[str] = []
    labels: list[str] = []
    for tab in data["tabs"]:
        if set(tab) != {"label", "roles"} or len(tab["roles"]) != 3:
            raise WorkflowError("each tab must declare a label and three roles")
        labels.append(tab["label"])
        roles.extend(tab["roles"])
    if labels != ["Build", "Review"] or len(set(roles)) != 6:
        raise WorkflowError("team.toml has invalid tab labels or duplicate roles")
    if any(not ROLE_RE.fullmatch(role) for role in roles):
        raise WorkflowError("team.toml contains an invalid role name")
    if set(data["prompts"]) != set(roles):
        raise WorkflowError("team.toml prompt keys must exactly match roles")
    prompt_root = (root / "herdr" / "prompts").resolve()
    for role, relative in data["prompts"].items():
        prompt = (root / "herdr" / relative).resolve()
        if prompt.parent != prompt_root or not prompt.is_file() or prompt.is_symlink():
            raise WorkflowError(f"unsafe or missing prompt for {role}")
        if prompt.stat().st_size > 16384:
            raise WorkflowError(f"prompt for {role} exceeds 16 KiB")
    return data


def check_version(binary: str) -> None:
    proc = subprocess.run([binary, "--version"], text=True, stdout=subprocess.PIPE, check=False)
    match = re.fullmatch(r"herdr (\d+)\.(\d+)\.(\d+)\s*", proc.stdout)
    if proc.returncode != 0 or not match or tuple(map(int, match.groups())) != SUPPORTED_HERDR:
        raise WorkflowError("this workflow currently requires Herdr 0.8.2")


def check_integration(binary: str) -> None:
    proc = subprocess.run([binary, "integration", "status"], text=True, stdout=subprocess.PIPE, check=False)
    if proc.returncode != 0 or not re.search(r"^codex: current \(v\d+\)", proc.stdout, re.MULTILINE):
        raise WorkflowError("Codex integration is not current; review README and run 'herdr integration install codex' explicitly")


@contextmanager
def reconcile_lock():
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    directory = state_home / "fedora-niri-dotfiles" / "herdr"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    directory.chmod(0o700)
    lock_path = directory / "reconcile.lock"
    with lock_path.open("a+", encoding="utf-8") as handle:
        os.chmod(lock_path, 0o600)
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def result_item(result: dict, key: str, id_key: str) -> str:
    item = result.get(key)
    if not isinstance(item, dict) or not isinstance(item.get(id_key), str):
        raise WorkflowError(f"Herdr response is missing {key}.{id_key}")
    return item[id_key]


def current_state(api: Herdr, manifest: dict, root: Path) -> tuple[dict | None, list[dict], list[dict], list[dict]]:
    workspaces = api.json("workspace", "list").get("workspaces")
    if not isinstance(workspaces, list):
        raise WorkflowError("workspace list has an unexpected schema")
    matches = [item for item in workspaces if item.get("label") == manifest["workspace"]]
    if len(matches) > 1:
        raise WorkflowError("conflict: duplicate Dotfiles Team workspaces")
    if not matches:
        return None, [], [], []
    workspace = matches[0]
    workspace_id = workspace.get("workspace_id")
    if not isinstance(workspace_id, str):
        raise WorkflowError("workspace has no opaque ID")
    tabs = api.json("tab", "list", "--workspace", workspace_id).get("tabs")
    panes = api.json("pane", "list", "--workspace", workspace_id).get("panes")
    agents = api.json("agent", "list").get("agents")
    if not all(isinstance(value, list) for value in (tabs, panes, agents)):
        raise WorkflowError("Herdr state has an unexpected schema")
    pane_ids = {pane.get("pane_id") for pane in panes}
    agents = [agent for agent in agents if agent.get("pane_id") in pane_ids]
    for pane in panes:
        cwd = pane.get("cwd")
        if not isinstance(cwd, str) or Path(cwd).resolve() != root:
            raise WorkflowError(f"conflict: pane {pane.get('pane_id')} has the wrong cwd")
    return workspace, tabs, panes, agents


def verify(manifest: dict, root: Path, workspace: dict | None, tabs: list[dict], panes: list[dict], agents: list[dict]) -> list[str]:
    drift: list[str] = []
    if workspace is None:
        return ["missing workspace: Dotfiles Team"]
    desired_labels = [tab["label"] for tab in manifest["tabs"]]
    live_labels = [tab.get("label") for tab in tabs]
    for label in desired_labels:
        if live_labels.count(label) != 1:
            drift.append(f"expected one {label} tab")
    if len(tabs) != 2:
        drift.append("workspace must contain exactly two tabs")
    role_to_tab = {role: tab["label"] for tab in manifest["tabs"] for role in tab["roles"]}
    names = [agent.get("name") for agent in agents if agent.get("name")]
    if len(names) != len(set(names)):
        drift.append("duplicate named agents")
    tab_labels = {tab.get("tab_id"): tab.get("label") for tab in tabs}
    for role, expected_tab in role_to_tab.items():
        matches = [agent for agent in agents if agent.get("name") == role]
        if len(matches) != 1:
            drift.append(f"expected one agent named {role}")
            continue
        agent = matches[0]
        if agent.get("agent") != manifest["agent_kind"]:
            drift.append(f"{role} is not a Codex agent")
        if tab_labels.get(agent.get("tab_id")) != expected_tab:
            drift.append(f"{role} is in the wrong tab")
        if agent.get("agent_status") == "unknown" or not agent.get("agent_session"):
            drift.append(f"{role} is not safely recognized")
    desired_roles = set(role_to_tab)
    extras = [name for name in names if name not in desired_roles]
    if extras:
        drift.append("unexpected named agents: " + ", ".join(sorted(extras)))
    for tab in tabs:
        count = sum(agent.get("tab_id") == tab.get("tab_id") for agent in agents)
        if count > manifest["max_agents_per_tab"]:
            drift.append(f"tab {tab.get('label')} exceeds the agent limit")
        pane_count = sum(pane.get("tab_id") == tab.get("tab_id") for pane in panes)
        if tab.get("label") in desired_labels and pane_count != 3:
            drift.append(f"tab {tab.get('label')} must contain exactly three panes")
    return drift


def empty_shell(api: Herdr, pane_id: str) -> bool:
    info = api.json("pane", "process-info", "--pane", pane_id).get("process_info")
    return isinstance(info, dict) and info.get("foreground_processes") == []


def prompt_role(api: Herdr, root: Path, role: str) -> None:
    instruction = f"Read {root / 'AGENTS.md'} and {root / 'herdr' / 'prompts' / (role + '.md')} completely, then wait for a coordinator task envelope."
    api.mutate("agent", "prompt", role, instruction)


def reconcile(api: Herdr, manifest: dict, root: Path) -> None:
    workspace, tabs, panes, agents = current_state(api, manifest, root)
    if workspace is None:
        result = api.mutate("workspace", "create", "--cwd", str(root), "--label", manifest["workspace"], "--no-focus")
        if api.dry_run:
            print("Would create Build and Review with three Codex roles each.")
            return
        workspace_id = result_item(result, "workspace", "workspace_id")
        root_tab = result_item(result, "tab", "tab_id")
        api.mutate("tab", "rename", root_tab, "Build")
    workspace, tabs, panes, agents = current_state(api, manifest, root)
    if workspace is None:
        raise WorkflowError("workspace creation did not converge")
    workspace_id = workspace["workspace_id"]

    labels = [tab.get("label") for tab in tabs]
    if len(labels) != len(set(labels)) or any(label not in {"Build", "Review"} for label in labels):
        raise WorkflowError("conflict: unexpected or duplicate tab labels")
    for desired in manifest["tabs"]:
        if desired["label"] not in labels:
            api.mutate("tab", "create", "--workspace", workspace_id, "--cwd", str(root), "--label", desired["label"], "--no-focus")
            if api.dry_run:
                continue
            workspace, tabs, panes, agents = current_state(api, manifest, root)

    if api.dry_run:
        print("Would add only missing panes and roles; conflicts would stop repair.")
        return

    workspace, tabs, panes, agents = current_state(api, manifest, root)
    desired_roles = {role for tab in manifest["tabs"] for role in tab["roles"]}
    named = [agent for agent in agents if agent.get("name")]
    if any(agent.get("name") not in desired_roles for agent in named):
        raise WorkflowError("conflict: unexpected named agent in managed workspace")
    tab_map = {tab["label"]: tab for tab in tabs}
    for desired in manifest["tabs"]:
        tab = tab_map[desired["label"]]
        tab_id = tab["tab_id"]
        tab_panes = [pane for pane in panes if pane.get("tab_id") == tab_id]
        tab_agents = [agent for agent in agents if agent.get("tab_id") == tab_id]
        wrong = [agent.get("name") for agent in tab_agents if agent.get("name") not in desired["roles"]]
        if wrong or len(tab_panes) > 3:
            raise WorkflowError(f"conflict: {desired['label']} has unexpected occupants or extra panes")
        while len(tab_panes) < 3:
            anchor = tab_panes[0]["pane_id"]
            result = api.mutate("pane", "split", "--pane", anchor, "--direction", "right", "--cwd", str(root), "--no-focus")
            result_item(result, "pane", "pane_id")
            workspace, tabs, panes, agents = current_state(api, manifest, root)
            tab_panes = [pane for pane in panes if pane.get("tab_id") == tab_id]
            tab_agents = [agent for agent in agents if agent.get("tab_id") == tab_id]
        missing = [role for role in desired["roles"] if not any(agent.get("name") == role for agent in tab_agents)]
        available = [pane for pane in tab_panes if not any(agent.get("pane_id") == pane.get("pane_id") for agent in tab_agents)]
        if len(available) != len(missing):
            raise WorkflowError(f"conflict: {desired['label']} cannot be repaired additively")
        for role, pane in zip(missing, available, strict=True):
            pane_id = pane["pane_id"]
            if not empty_shell(api, pane_id):
                raise WorkflowError(f"conflict: pane {pane_id} is not an empty shell")
            api.mutate("agent", "start", role, "--kind", manifest["agent_kind"], "--pane", pane_id)
            prompt_role(api, root, role)
            workspace, tabs, panes, agents = current_state(api, manifest, root)

    drift = verify(manifest, root, *current_state(api, manifest, root))
    if drift:
        raise WorkflowError("repair incomplete: " + "; ".join(drift))
    print("Herdr team is healthy.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--validate-config", action="store_true")
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--dry-run", action="store_true")
    modes.add_argument("--setup", action="store_true")
    modes.add_argument("--repair", action="store_true")
    args = parser.parse_args()
    try:
        root = repo_root()
        manifest = load_manifest(root)
        if args.validate_config:
            print("team.toml and role prompts are valid.")
            return 0
        binary = trusted_executable("herdr")
        check_version(binary)
        check_integration(binary)
        if os.environ.get("HERDR_ENV") != "1" or os.environ.get("HERDR_SESSION") != manifest["session"]:
            raise WorkflowError(f"run this command inside the {manifest['session']} Herdr session")
        api = Herdr(binary, manifest["session"], dry_run=args.dry_run)
        if args.check:
            drift = verify(manifest, root, *current_state(api, manifest, root))
            if drift:
                print("Herdr team drift:", file=sys.stderr)
                for item in drift:
                    print(f"- {item}", file=sys.stderr)
                return 1
            print("Herdr team is healthy.")
            return 0
        with reconcile_lock():
            reconcile(api, manifest, root)
        return 0
    except (OSError, subprocess.TimeoutExpired, WorkflowError, tomllib.TOMLDecodeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
