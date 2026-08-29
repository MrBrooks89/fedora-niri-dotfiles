#!/usr/bin/env python3
"""Stateful Herdr 0.8.2 fake used only by repository tests."""
import json, os, sys
from pathlib import Path

state_path=Path(os.environ["FAKE_HERDR_STATE"])
state=json.loads(state_path.read_text())
args=sys.argv[1:]
if args==["--version"]: print("herdr 0.8.2"); raise SystemExit
if args==["integration","status"]: print("codex: current (v8) (/tmp/fake)"); raise SystemExit
selected=False
if args[:2]==["--session","fedora-niri-dotfiles"]: selected=True; args=args[2:]
command=" ".join(args)
state.setdefault("calls",[]).append({"selected":selected,"args":args})
if command==state.get("malformed_on"):
    state_path.write_text(json.dumps(state)); print("not-json"); raise SystemExit
if command==state.get("error_on"):
    state_path.write_text(json.dumps(state)); print(json.dumps({"error":{"message":"fixture failure"}})); raise SystemExit(1)
if command==state.get("result_error_on"):
    state_path.write_text(json.dumps(state)); print(json.dumps({"error":{"message":"fixture result error"}})); raise SystemExit

def save(): state_path.write_text(json.dumps(state))
def response(result): save(); print(json.dumps({"id":"fake","result":result}))
def mutation(): state.setdefault("mutations",[]).append(command)
def option(name): return args[args.index(name)+1]

if args==["session","list","--json"]:
    save(); print(json.dumps({"sessions":[{"name":"fedora-niri-dotfiles","running":True,"socket_path":state["socket"]}]})); raise SystemExit
if args[:2]==["pane","current"]: response({"pane":{"pane_id":state["current_pane"],"workspace_id":state["current_workspace"]}}); raise SystemExit
if args==["workspace","list"]: response({"workspaces":state["workspaces"]}); raise SystemExit
if args[:2]==["tab","list"]: response({"tabs":[t for t in state["tabs"] if t["workspace_id"]==option("--workspace")]}); raise SystemExit
if args[:2]==["pane","list"]: response({"panes":[p for p in state["panes"] if p["workspace_id"]==option("--workspace")]}); raise SystemExit
if args==["agent","list"]:
    state["agent_reads"]=state.get("agent_reads",0)+1
    if state.get("restore_after_reads") and state["agent_reads"]>=state["restore_after_reads"] and state.get("pending_agent"):
        state["agents"].append(state.pop("pending_agent"))
    response({"agents":state["agents"]}); raise SystemExit
if args[:2]==["pane","process-info"]:
    pid=option("--pane"); response({"process_info":{"pane_id":pid,"foreground_processes":state.get("processes",{}).get(pid,[])}}); raise SystemExit
if args[:2]==["workspace","rename"]:
    mutation(); wid=args[2]; next(w for w in state["workspaces"] if w["workspace_id"]==wid)["label"]=args[3]; response({"workspace":{"workspace_id":wid}}); raise SystemExit
if args[:2]==["tab","rename"]:
    mutation(); tid=args[2]; next(t for t in state["tabs"] if t["tab_id"]==tid)["label"]=args[3]; response({"tab":{"tab_id":tid}}); raise SystemExit
if args[:2]==["tab","create"]:
    mutation(); state["next_tab"]+=1; tid=f"opaque-tab-{state['next_tab']}"; pid=f"opaque-pane-{state['next_pane']}"; state["next_pane"]+=1
    wid=option("--workspace"); label=option("--label"); cwd=option("--cwd")
    state["tabs"].append({"tab_id":tid,"workspace_id":wid,"label":label}); state["panes"].append({"pane_id":pid,"tab_id":tid,"workspace_id":wid,"cwd":cwd})
    response({"tab":{"tab_id":tid},"root_pane":{"pane_id":pid}}); raise SystemExit
if args[:2]==["pane","split"]:
    mutation(); anchor=next(p for p in state["panes"] if p["pane_id"]==option("--pane")); pid=f"opaque-pane-{state['next_pane']}"; state["next_pane"]+=1
    state["panes"].append({"pane_id":pid,"tab_id":anchor["tab_id"],"workspace_id":anchor["workspace_id"],"cwd":option("--cwd")}); response({"pane":{"pane_id":pid}}); raise SystemExit
if args[:2]==["agent","start"]:
    mutation(); role=args[2]; pane=next(p for p in state["panes"] if p["pane_id"]==option("--pane")); pane.update({"agent":"codex","agent_status":"idle","agent_session":{"kind":"id","value":"session-"+role}})
    state["agents"].append({**pane,"name":role})
    if state.get("start_fail_after_role")==role:
        save(); print(json.dumps({"error":{"message":"start returned failure after retaining name"}}),file=sys.stderr); raise SystemExit(1)
    if state.get("start_not_ready_role")==role:
        pane["agent_status"]="blocked"; state["agents"][-1]["agent_status"]="blocked"; save(); print(json.dumps({"error":{"code":"agent_not_ready"}}),file=sys.stderr); raise SystemExit(1)
    response({"agent":{"name":role,"pane_id":pane["pane_id"]}}); raise SystemExit
if args[:2]==["agent","prompt"]:
    mutation(); role=args[2]; failures=state.setdefault("prompt_failures",{}).get(role,0)
    if failures:
        state["prompt_failures"][role]=failures-1; save(); print(json.dumps({"error":{"message":"prompt timeout"}}),file=sys.stderr); raise SystemExit(1)
    response({"agent":{"name":role}}); raise SystemExit
save(); print(json.dumps({"error":{"message":"unsupported fake command: "+command}})); raise SystemExit(1)
