#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("dotfiles_herdr_team", ROOT / "herdr" / "team.py")
assert SPEC and SPEC.loader
TEAM = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TEAM)


class ManifestTests(unittest.TestCase):
    def test_manifest_is_canonical(self):
        manifest = TEAM.load_manifest(ROOT)
        self.assertEqual(manifest["session"], "fedora-niri-dotfiles")
        self.assertEqual(
            [(tab["label"], tab["roles"]) for tab in manifest["tabs"]],
            [
                ("Build", ["coordinator", "implementation", "integration"]),
                ("Review", ["validation", "security", "release"]),
            ],
        )
        self.assertLessEqual(manifest["max_agents_per_tab"], 4)


class StateTests(unittest.TestCase):
    def setUp(self):
        self.manifest = TEAM.load_manifest(ROOT)
        self.workspace = {"workspace_id": "opaque-workspace", "label": "Dotfiles Team"}
        self.tabs = [
            {"tab_id": "opaque-build", "label": "Build"},
            {"tab_id": "opaque-review", "label": "Review"},
        ]
        role_tabs = {
            "coordinator": "opaque-build", "implementation": "opaque-build", "integration": "opaque-build",
            "validation": "opaque-review", "security": "opaque-review", "release": "opaque-review",
        }
        self.panes = []
        self.agents = []
        for index, (role, tab_id) in enumerate(role_tabs.items(), 1):
            pane_id = f"opaque-pane-{index}"
            self.panes.append({"pane_id": pane_id, "tab_id": tab_id, "cwd": str(ROOT)})
            self.agents.append({
                "pane_id": pane_id, "tab_id": tab_id, "name": role,
                "agent": "codex", "agent_status": "working",
                "agent_session": {"kind": "id", "value": f"session-{index}"},
            })

    def test_healthy_topology(self):
        self.assertEqual(
            TEAM.verify(self.manifest, ROOT, self.workspace, self.tabs, self.panes, self.agents), []
        )

    def test_opaque_ids_and_order_do_not_matter(self):
        self.assertEqual(
            TEAM.verify(self.manifest, ROOT, self.workspace, list(reversed(self.tabs)),
                        list(reversed(self.panes)), list(reversed(self.agents))), []
        )

    def test_unknown_agent_fails_closed(self):
        self.agents[0]["agent_status"] = "unknown"
        self.assertIn("coordinator is not safely recognized",
                      TEAM.verify(self.manifest, ROOT, self.workspace, self.tabs, self.panes, self.agents))

    def test_wrong_tab_and_extra_agent_are_reported(self):
        self.agents[0]["tab_id"] = "opaque-review"
        self.agents.append({"name": "intruder", "tab_id": "opaque-build", "agent": "codex"})
        drift = TEAM.verify(self.manifest, ROOT, self.workspace, self.tabs, self.panes, self.agents)
        self.assertIn("coordinator is in the wrong tab", drift)
        self.assertIn("unexpected named agents: intruder", drift)


if __name__ == "__main__":
    unittest.main()
