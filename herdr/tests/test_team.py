#!/usr/bin/env python3
from __future__ import annotations
import atexit, importlib.util, json, os, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
TEAM=ROOT/"herdr/team.py"
FAKE=ROOT/"herdr/tests/fake-herdr.py"
SPEC=importlib.util.spec_from_file_location("dotfiles_team",TEAM); MODULE=importlib.util.module_from_spec(SPEC); sys.modules[SPEC.name]=MODULE; SPEC.loader.exec_module(MODULE)

def pristine(root=ROOT):
    return {"socket":"/tmp/fake-session/herdr.sock","current_pane":"opaque-pane-1","current_workspace":"opaque-workspace-1","next_tab":2,"next_pane":2,"workspaces":[{"workspace_id":"opaque-workspace-1","label":"Workspace 1"}],"tabs":[{"tab_id":"opaque-tab-1","workspace_id":"opaque-workspace-1","label":"Tab 1"}],"panes":[{"pane_id":"opaque-pane-1","tab_id":"opaque-tab-1","workspace_id":"opaque-workspace-1","cwd":str(root)}],"agents":[],"processes":{},"calls":[],"mutations":[]}

class Harness:
    def __init__(self,state):
        self.path=Path(tempfile.mkdtemp()); atexit.register(shutil.rmtree,self.path,True); self.state_path=self.path/"state.json"; self.state_path.write_text(json.dumps(state)); self.bin=self.path/"bin"; self.bin.mkdir(); (self.bin/"herdr").symlink_to(FAKE)
    def run(self,*args,extra=None):
        env=os.environ.copy(); env.update({"PATH":f"{self.bin}:/usr/bin:/bin","FAKE_HERDR_STATE":str(self.state_path),"XDG_STATE_HOME":str(self.path/"state"),"HERDR_ENV":"1","HERDR_SOCKET_PATH":"/tmp/fake-session/herdr.sock","HERDR_PANE_ID":"opaque-pane-1","HERDR_TAB_ID":"opaque-tab-1","HERDR_WORKSPACE_ID":"opaque-workspace-1"}); env.pop("HERDR_SESSION",None)
        if extra: env.update(extra)
        return subprocess.run([str(TEAM),*args,"--settle-seconds","0.05"],cwd=ROOT,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    def state(self): return json.loads(self.state_path.read_text())

class EndToEnd(unittest.TestCase):
    def test_fresh_setup_and_noop_rerun_without_herdr_session(self):
        h=Harness(pristine()); first=h.run("--setup"); self.assertEqual(first.returncode,0,first.stderr)
        state=h.state(); self.assertEqual([w["label"] for w in state["workspaces"]],["Dotfiles Team"]); self.assertEqual(sorted(t["label"] for t in state["tabs"]),["Build","Review"]); self.assertEqual(sorted(a["name"] for a in state["agents"]),["coordinator","implementation","integration","release","security","validation"]); self.assertEqual(len(state["panes"]),6)
        self.assertFalse(any(call.startswith("workspace create") for call in state["mutations"])); self.assertTrue(any(call.startswith("workspace rename opaque-workspace-1") for call in state["mutations"])); self.assertTrue(all("--no-focus" in call and "--cwd" in call for call in state["mutations"] if call.startswith(("tab create","pane split")))); self.assertTrue(all("--pane opaque-pane-" in call for call in state["mutations"] if call.startswith("agent start")))
        before=len(state["mutations"]); second=h.run("--repair"); self.assertEqual(second.returncode,0,second.stderr); self.assertEqual(len(h.state()["mutations"]),before)

    def test_additive_missing_agent_repair(self):
        h=Harness(pristine()); self.assertEqual(h.run("--setup").returncode,0); state=h.state(); victim=next(a for a in state["agents"] if a["name"]=="release"); state["agents"].remove(victim); pane=next(p for p in state["panes"] if p["pane_id"]==victim["pane_id"]); [pane.pop(k,None) for k in ("agent","agent_status","agent_session")]; h.state_path.write_text(json.dumps(state)); before=list(state["mutations"])
        result=h.run("--repair"); self.assertEqual(result.returncode,0,result.stderr); added=h.state()["mutations"][len(before):]; self.assertEqual(sum("agent start release" in x for x in added),1); self.assertFalse(any(x.startswith("pane split") or x.startswith("tab create") for x in added))

    def test_additive_missing_pane_and_agent_repair(self):
        h=Harness(pristine()); self.assertEqual(h.run("--setup").returncode,0); state=h.state(); victim=next(a for a in state["agents"] if a["name"]=="security"); state["agents"].remove(victim); state["panes"]=[p for p in state["panes"] if p["pane_id"]!=victim["pane_id"]]; h.state_path.write_text(json.dumps(state)); before=len(state["mutations"])
        result=h.run("--repair"); self.assertEqual(result.returncode,0,result.stderr); added=h.state()["mutations"][before:]; self.assertEqual(sum(x.startswith("pane split") for x in added),1); self.assertEqual(sum("agent start security" in x for x in added),1)

    def test_partial_failure_retry_converges(self):
        state=pristine(); state["error_on"]="agent start integration --kind codex --pane opaque-pane-3"; h=Harness(state)
        first=h.run("--setup"); self.assertNotEqual(first.returncode,0); state=h.state(); self.assertGreater(len(state["mutations"]),0); state.pop("error_on"); h.state_path.write_text(json.dumps(state))
        second=h.run("--repair"); self.assertEqual(second.returncode,0,second.stderr); self.assertEqual(len(h.state()["agents"]),6)

    def test_delayed_restore_settles_without_replacement(self):
        state=pristine(); state["workspaces"][0]["label"]="Dotfiles Team"; state["tabs"][0]["label"]="Build"; pane=state["panes"][0]; pane["agent_session"]={"kind":"id","value":"saved"}; state["pending_agent"]={**pane,"name":"coordinator","agent":"codex","agent_status":"working"}; state["restore_after_reads"]=2
        # Remaining topology is intentionally incomplete, but the restored role must not be started again.
        h=Harness(state); result=h.run("--dry-run"); self.assertEqual(result.returncode,0,result.stderr); self.assertFalse(any("agent start coordinator" in x for x in h.state()["mutations"]))

    def test_conflicts_make_zero_mutations(self):
        cases={"wrong-tab":lambda s: self._agent(s,"coordinator","Review"),"wrong-kind":lambda s:self._agent(s,"coordinator","Build",kind="claude"),"unknown":lambda s:self._agent(s,"coordinator","Build",status="unknown"),"occupied":lambda s:s["processes"].update({"opaque-pane-1":[{"name":"vim"}]}),"stale-restore":lambda s:s["panes"][0].update({"agent_session":{"kind":"id","value":"stale"}}),"malformed":lambda s:s.update({"malformed_on":"workspace list"})}
        for name,change in cases.items():
            with self.subTest(name=name):
                state=pristine(); state["workspaces"][0]["label"]="Dotfiles Team"; state["tabs"][0]["label"]="Build"; change(state); h=Harness(state); result=h.run("--repair"); self.assertNotEqual(result.returncode,0); self.assertEqual(h.state()["mutations"],[])

    def _agent(self,state,role,tab,kind="codex",status="idle"):
        if tab=="Review": state["tabs"].append({"tab_id":"opaque-review","workspace_id":"opaque-workspace-1","label":"Review"}); state["panes"].append({"pane_id":"opaque-review-pane","tab_id":"opaque-review","workspace_id":"opaque-workspace-1","cwd":str(ROOT)}); pane=state["panes"][-1]
        else: pane=state["panes"][0]
        pane.update({"agent":kind,"agent_status":status,"agent_session":{"kind":"id","value":"s"}}); state["agents"].append({**pane,"name":role})

    def test_blocked_and_working_agents_are_preserved(self):
        h=Harness(pristine()); self.assertEqual(h.run("--setup").returncode,0); state=h.state(); state["agents"][0]["agent_status"]="blocked"; state["agents"][1]["agent_status"]="working"; h.state_path.write_text(json.dumps(state)); before=len(state["mutations"])
        result=h.run("--repair"); self.assertEqual(result.returncode,0,result.stderr); self.assertEqual(len(h.state()["mutations"]),before)

    def test_response_error_is_nonmutating(self):
        for field in ("error_on","result_error_on"):
            with self.subTest(field=field):
                state=pristine(); state[field]="workspace list"; h=Harness(state); result=h.run("--setup"); self.assertNotEqual(result.returncode,0); self.assertEqual(h.state()["mutations"],[])

class ManifestValidation(unittest.TestCase):
    def test_bad_policy_values(self):
        original=(ROOT/"herdr/team.toml").read_text()
        for replacement in ("max_agents_per_tab = 0","max_agents_per_tab = true","workflow_version = 1"):
            with self.subTest(replacement=replacement), tempfile.TemporaryDirectory() as tmp:
                text=original.replace("max_agents_per_tab = 4",replacement) if replacement.startswith("max") else original.replace('workflow_version = "1.0.0"',replacement)
                path=Path(tmp)/"bad.toml"; path.write_text(text)
                with self.assertRaises(MODULE.WorkflowError): MODULE.load_manifest(ROOT,path)

if __name__=="__main__": unittest.main()
