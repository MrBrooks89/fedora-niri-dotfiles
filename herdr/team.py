#!/usr/bin/env python3
"""Validate and additively reconcile the persistent dotfiles Herdr team."""
from __future__ import annotations
import argparse, fcntl, hashlib, json, os, re, shutil, stat, subprocess, sys, tempfile, time, tomllib
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any

ROLE_RE = re.compile(r"^[a-z][a-z0-9_-]{0,31}$")
VERSION_RE = re.compile(r"^[1-9][0-9]*\.[0-9]+\.[0-9]+$")
SUPPORTED_HERDR = (0, 8, 2)

class WorkflowError(RuntimeError): pass

@dataclass(frozen=True)
class Operation:
    action: str
    tab: str = ""
    role: str = ""
    target: str = ""

@dataclass
class Snapshot:
    workspaces: list[dict[str, Any]]
    workspace: dict[str, Any] | None
    tabs: list[dict[str, Any]]
    panes: list[dict[str, Any]]
    agents: list[dict[str, Any]]
    processes: dict[str, list[dict[str, Any]]]

def trusted_executable(name: str) -> str:
    candidate = shutil.which(name)
    if not candidate: raise WorkflowError(f"{name} is not installed")
    path, details = Path(candidate).resolve(), Path(candidate).resolve().stat()
    system = path.is_relative_to("/usr/bin") or path.is_relative_to("/usr/local/bin")
    if not stat.S_ISREG(details.st_mode): raise WorkflowError(f"{name} is not a regular file")
    if (details.st_uid not in {0, os.getuid()} and not system) or details.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise WorkflowError(f"{name} executable has unsafe ownership or permissions")
    return str(path)

def repo_root() -> Path:
    root = Path(__file__).resolve().parent.parent
    proc = subprocess.run([trusted_executable("git"), "-C", str(root), "rev-parse", "--show-toplevel"], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if proc.returncode or Path(proc.stdout.strip()).resolve() != root or not (root / "AGENTS.md").is_file():
        raise WorkflowError("team.py is not inside the canonical dotfiles checkout")
    return root

def load_manifest(root: Path, path: Path | None = None) -> dict[str, Any]:
    with (path or root / "herdr/team.toml").open("rb") as handle: data = tomllib.load(handle)
    required = {"schema_version","workflow_version","session","workspace","agent_kind","max_agents_per_tab","tabs","prompts"}
    if set(data) != required or type(data["schema_version"]) is not int or data["schema_version"] != 1: raise WorkflowError("unsupported manifest schema")
    for key in ("workflow_version","session","workspace","agent_kind"):
        if type(data[key]) is not str or not data[key]: raise WorkflowError(f"{key} must be a nonempty string")
    if not VERSION_RE.fullmatch(data["workflow_version"]): raise WorkflowError("workflow_version must use MAJOR.MINOR.PATCH")
    if data["session"] == "default" or not ROLE_RE.fullmatch(data["session"]): raise WorkflowError("unsafe session name")
    limit = data["max_agents_per_tab"]
    if type(limit) is not int or not 1 <= limit <= 4: raise WorkflowError("max_agents_per_tab must be an integer from 1 through 4")
    if data["agent_kind"] != "opencode" or type(data["tabs"]) is not list or len(data["tabs"]) != 2: raise WorkflowError("manifest must declare opencode and exactly two tabs")
    roles, labels = [], []
    for tab in data["tabs"]:
        if type(tab) is not dict or set(tab) != {"label","roles"} or type(tab["label"]) is not str or type(tab["roles"]) is not list: raise WorkflowError("invalid tab declaration")
        if not tab["roles"] or len(tab["roles"]) > limit or any(type(role) is not str for role in tab["roles"]): raise WorkflowError("tab role cardinality violates policy")
        labels.append(tab["label"]); roles.extend(tab["roles"])
    canonical = ["coordinator","implementation","integration","validation","security","release"]
    if labels != ["Build","Review"] or roles != canonical or len(set(roles)) != 6 or any(not ROLE_RE.fullmatch(r) for r in roles): raise WorkflowError("manifest must declare canonical ordered tabs and roles")
    if type(data["prompts"]) is not dict or set(data["prompts"]) != set(roles): raise WorkflowError("prompt keys must exactly match roles")
    prompt_root = (root / "herdr/prompts").resolve()
    for role, relative in data["prompts"].items():
        if type(relative) is not str: raise WorkflowError(f"prompt path for {role} must be a string")
        prompt = (root / "herdr" / relative).resolve()
        if prompt.parent != prompt_root or not prompt.is_file() or prompt.is_symlink() or prompt.stat().st_size > 16384: raise WorkflowError(f"unsafe, missing, or oversized prompt for {role}")
    return data

class Herdr:
    def __init__(self, binary: str, session: str, dry_run=False): self.binary, self.session, self.dry_run = binary, session, dry_run
    def command(self, *args: str, selected=True) -> list[str]: return [self.binary, *( ["--session",self.session] if selected else []), *args]
    def run_json(self, *args: str, selected=True) -> dict[str, Any]:
        proc = subprocess.run(self.command(*args, selected=selected), text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
        if proc.returncode: raise WorkflowError(f"Herdr command failed ({proc.returncode}): {(proc.stderr.strip() or proc.stdout.strip())[:1000]}")
        try: value = json.loads(proc.stdout)
        except json.JSONDecodeError as exc: raise WorkflowError("Herdr returned malformed JSON") from exc
        if not isinstance(value, dict): raise WorkflowError("Herdr JSON response must be an object")
        if selected:
            if not isinstance(value.get("result"), dict) or value.get("error") is not None: raise WorkflowError("Herdr JSON response is missing a successful result")
            return value["result"]
        return value
    def mutate(self, *args: str) -> dict[str, Any]:
        print("+", " ".join(self.command(*args)))
        return {} if self.dry_run else self.run_json(*args)

def check_version(binary):
    proc = subprocess.run([binary,"--version"], text=True, stdout=subprocess.PIPE)
    match = re.fullmatch(r"herdr (\d+)\.(\d+)\.(\d+)\s*", proc.stdout)
    if proc.returncode or not match or tuple(map(int,match.groups())) != SUPPORTED_HERDR: raise WorkflowError("this workflow requires Herdr 0.8.2")

def check_integration(binary):
    proc = subprocess.run([binary,"integration","status"], text=True, stdout=subprocess.PIPE)
    if proc.returncode or not re.search(r"^opencode: current \(v\d+\)",proc.stdout,re.MULTILINE): raise WorkflowError("opencode integration is not current; install it explicitly")

def identify_session(api: Herdr, env: dict[str,str]):
    required = ("HERDR_SOCKET_PATH","HERDR_PANE_ID","HERDR_TAB_ID","HERDR_WORKSPACE_ID")
    if env.get("HERDR_ENV") != "1" or any(not env.get(k) for k in required): raise WorkflowError("run from a Herdr-managed pane with complete socket and pane context")
    sessions = api.run_json("session","list","--json",selected=False).get("sessions")
    if not isinstance(sessions,list): raise WorkflowError("session list has an unexpected schema")
    inherited = Path(env["HERDR_SOCKET_PATH"]).resolve(strict=False)
    matches = [s for s in sessions if isinstance(s,dict) and s.get("running") is True and isinstance(s.get("socket_path"),str) and Path(s["socket_path"]).resolve(strict=False)==inherited]
    if len(matches)!=1 or matches[0].get("name")!=api.session: raise WorkflowError(f"inherited socket is not the running {api.session} session")
    current = api.run_json("pane","current","--current").get("pane")
    if not isinstance(current,dict) or current.get("pane_id")!=env["HERDR_PANE_ID"] or current.get("workspace_id")!=env["HERDR_WORKSPACE_ID"]: raise WorkflowError("pane context does not match selected session")

@contextmanager
def reconcile_lock():
    directory = Path(os.environ.get("XDG_STATE_HOME",Path.home()/".local/state"))/"fedora-niri-dotfiles/herdr"
    directory.mkdir(mode=0o700,parents=True,exist_ok=True); directory.chmod(0o700)
    lock = directory/"reconcile.lock"
    with lock.open("a+") as handle:
        os.chmod(lock,0o600); fcntl.flock(handle,fcntl.LOCK_EX); yield

def contract_file():
    return Path(os.environ.get("XDG_STATE_HOME",Path.home()/".local/state"))/"fedora-niri-dotfiles/herdr/role-contracts.json"

def load_contracts():
    path=contract_file()
    if not path.exists(): return {}
    data=json.loads(path.read_text())
    if not isinstance(data,dict) or data.get("schema_version")!=1 or not isinstance(data.get("roles"),dict): raise WorkflowError("invalid role-contract ledger")
    required={"workflow_version","prompt_sha256","agent_session","status","attempts","last_error"}
    for role,record in data["roles"].items():
        if not ROLE_RE.fullmatch(role) or not isinstance(record,dict) or set(record)!=required or record["status"] not in {"attempting","failed","delivered"} or type(record["attempts"]) is not int or record["attempts"]<1 or not all(isinstance(record[k],str) for k in required-{"attempts"}): raise WorkflowError("invalid role-contract record")
    return data["roles"]

def write_contracts(records):
    path=contract_file(); path.parent.mkdir(mode=0o700,parents=True,exist_ok=True); path.parent.chmod(0o700)
    fd,name=tempfile.mkstemp(prefix=".role-contracts.",dir=path.parent); os.close(fd); temporary=Path(name)
    try: temporary.write_text(json.dumps({"schema_version":1,"roles":records},indent=2,sort_keys=True)+"\n"); temporary.chmod(0o600); os.replace(temporary,path)
    finally:
        if temporary.exists(): temporary.unlink()

def contract_identity(manifest,root,role,agent):
    prompt=(root/"herdr"/manifest["prompts"][role]).read_bytes(); session=agent.get("agent_session",{}).get("value")
    return manifest["workflow_version"],hashlib.sha256(prompt).hexdigest(),session if isinstance(session,str) else ""

def contract_current(records,manifest,root,role,agent):
    version,prompt_sha,session=contract_identity(manifest,root,role,agent); record=records.get(role)
    return isinstance(record,dict) and (record.get("workflow_version"),record.get("prompt_sha256"),record.get("agent_session"))==(version,prompt_sha,session)

def contract_delivered(records,manifest,root,role,agent):
    return contract_current(records,manifest,root,role,agent) and records[role]["status"]=="delivered"

def items(result,key):
    value=result.get(key)
    if not isinstance(value,list) or any(not isinstance(x,dict) for x in value): raise WorkflowError(f"unexpected {key} schema")
    return value

def result_id(result,key,id_key):
    value=result.get(key)
    if not isinstance(value,dict) or not isinstance(value.get(id_key),str): raise WorkflowError(f"missing {key}.{id_key}")
    return value[id_key]

def discover(api, manifest, root):
    workspaces=items(api.run_json("workspace","list"),"workspaces")
    matching=[w for w in workspaces if w.get("label")==manifest["workspace"]]
    workspace=matching[0] if len(matching)==1 else (workspaces[0] if not matching and len(workspaces)==1 else None)
    if workspace is None: return Snapshot(workspaces,None,[],[],items(api.run_json("agent","list"),"agents"),{})
    wid=workspace.get("workspace_id")
    if not isinstance(wid,str): raise WorkflowError("workspace missing opaque ID")
    tabs=items(api.run_json("tab","list","--workspace",wid),"tabs"); panes=items(api.run_json("pane","list","--workspace",wid),"panes")
    pane_ids={p.get("pane_id") for p in panes}; agents=[a for a in items(api.run_json("agent","list"),"agents") if a.get("pane_id") in pane_ids]
    processes={}
    for pane in panes:
        pid=pane.get("pane_id"); info=api.run_json("pane","process-info","--pane",str(pid)).get("process_info")
        if not isinstance(pid,str) or not isinstance(info,dict) or not isinstance(info.get("foreground_processes"),list): raise WorkflowError("unexpected process-info schema")
        processes[pid]=info["foreground_processes"]
    return Snapshot(workspaces,workspace,tabs,panes,agents,processes)

def restore_pending(snapshot):
    occupied={a.get("pane_id") for a in snapshot.agents}
    return any(p.get("agent_session") and p.get("pane_id") not in occupied for p in snapshot.panes)

def settle_restore(api,manifest,root,seconds):
    snapshot=discover(api,manifest,root); deadline=time.monotonic()+max(0,seconds)
    while restore_pending(snapshot) and time.monotonic()<deadline:
        time.sleep(min(.2,max(0,deadline-time.monotonic()))); snapshot=discover(api,manifest,root)
    return snapshot

def plan(snapshot,manifest,root,contracts):
    ops, init_ops, conflicts=[],[],[]
    if len(snapshot.workspaces)!=1 or snapshot.workspace is None: return [],["session must contain exactly one workspace"]
    managed=snapshot.workspace.get("label")==manifest["workspace"]
    if not managed:
        pristine=len(snapshot.tabs)==1 and len(snapshot.panes)==1 and not snapshot.agents and snapshot.panes[0].get("cwd") and Path(snapshot.panes[0]["cwd"]).resolve()==root and snapshot.processes.get(snapshot.panes[0].get("pane_id"))==[]
        if not pristine: return [],["sole initial workspace is not pristine and cannot be adopted"]
        ops += [Operation("rename_workspace",target=str(snapshot.workspace.get("workspace_id"))),Operation("rename_tab",tab="Build",target=str(snapshot.tabs[0].get("tab_id")))]
    desired={t["label"]:t["roles"] for t in manifest["tabs"]}; live_labels=[t.get("label") for t in snapshot.tabs]
    if managed:
        extra=[str(x) for x in live_labels if x not in desired]
        dup=[x for x in desired if live_labels.count(x)>1]
        if extra: conflicts.append("unexpected tabs: "+", ".join(sorted(extra)))
        if dup: conflicts.append("duplicate tabs: "+", ".join(sorted(dup)))
    for pane in snapshot.panes:
        cwd=pane.get("cwd")
        if not isinstance(cwd,str) or Path(cwd).resolve()!=root: conflicts.append(f"pane {pane.get('pane_id')} has wrong cwd")
    if restore_pending(snapshot): conflicts.append("native agent restore did not settle")
    role_tab={r:l for l,roles in desired.items() for r in roles}; named=[a for a in snapshot.agents if a.get("name")]
    for role,expected in role_tab.items():
        matches=[a for a in named if a.get("name")==role]
        if len(matches)>1: conflicts.append(f"duplicate agent name: {role}")
        elif matches:
            agent=matches[0]; label=next((t.get("label") for t in snapshot.tabs if t.get("tab_id")==agent.get("tab_id")),None)
            if not managed and len(snapshot.tabs)==1: label="Build"
            if label!=expected: conflicts.append(f"{role} is in the wrong tab")
            if agent.get("agent")!=manifest["agent_kind"]: conflicts.append(f"{role} has wrong agent kind")
            if agent.get("agent_status")=="unknown" or not agent.get("agent_session"): conflicts.append(f"{role} is not safely recognized")
            elif not contract_delivered(contracts,manifest,root,role,agent):
                if agent.get("agent_status")=="blocked": conflicts.append(f"{role} is blocked and its role contract is uninitialized")
                elif agent.get("agent_status") not in {"idle","done"}: conflicts.append(f"{role} is not settled for role initialization")
                elif contract_current(contracts,manifest,root,role,agent) and contracts[role]["attempts"]>=2: conflicts.append(f"{role} role initialization exhausted its single retry")
                else: init_ops.append(Operation("initialize",role=role))
    extras=sorted(str(a.get("name")) for a in named if a.get("name") not in role_tab)
    if extras: conflicts.append("unexpected named agents: "+", ".join(extras))
    if any(not a.get("name") for a in snapshot.agents): conflicts.append("unnamed recognized agent occupies topology")
    if conflicts: return [],sorted(set(conflicts))
    tab_by_label={t.get("label"):t for t in snapshot.tabs}
    if not managed: tab_by_label={"Build":snapshot.tabs[0]}
    occupied={a.get("pane_id") for a in snapshot.agents}
    for label,roles in desired.items():
        tab=tab_by_label.get(label)
        if tab is None: ops.append(Operation("create_tab",tab=label)); panes=[{}]; agents=[]; free=[f"new:{label}:0"]
        else:
            panes=[p for p in snapshot.panes if p.get("tab_id")==tab.get("tab_id")]; agents=[a for a in snapshot.agents if a.get("tab_id")==tab.get("tab_id")]; free=[]
            if len(panes)>len(roles): conflicts.append(f"{label} has extra panes")
            for pane in panes:
                pid=pane.get("pane_id")
                if pid not in occupied:
                    if pane.get("agent_session"): conflicts.append(f"pane {pid} retains restore metadata")
                    elif snapshot.processes.get(pid)!=[]: conflicts.append(f"pane {pid} is occupied")
                    else: free.append(str(pid))
        missing=[r for r in roles if not any(a.get("name")==r for a in agents)]
        for index in range(len(roles)-len(panes)):
            token=f"new:{label}:{len(panes)+index}"; ops.append(Operation("split",tab=label,target=token)); free.append(token)
        if len(free)!=len(missing): conflicts.append(f"{label} cannot map missing roles to empty panes")
        else:
            for role,target in zip(missing,free,strict=True): ops.append(Operation("start",tab=label,role=role,target=target)); init_ops.append(Operation("initialize",role=role))
    ops.extend(init_ops)
    return ([],sorted(set(conflicts))) if conflicts else (ops,[])

def verify(snapshot,manifest,root,contracts):
    ops,conflicts=plan(snapshot,manifest,root,contracts)
    if conflicts:return conflicts
    if snapshot.workspace.get("label")!=manifest["workspace"]:return ["workspace has not been adopted"]
    return [] if not ops else [f"pending operation: {op.action} {op.tab or op.role}" for op in ops]

def assert_transition(api,manifest,root,op,tokens):
    snap=discover(api,manifest,root)
    if op.action=="rename_workspace" and snap.workspace.get("label")!=manifest["workspace"]: raise WorkflowError("workspace rename did not converge")
    if op.action in {"rename_tab","create_tab"} and not any(t.get("label")==op.tab for t in snap.tabs): raise WorkflowError("tab operation did not converge")
    if op.action=="split" and op.target not in tokens: raise WorkflowError("split response missing pane ID")
    if op.action=="start" and not any(a.get("name")==op.role for a in snap.agents): raise WorkflowError("agent start did not converge")

def apply_plan(api,manifest,root,operations,contracts):
    tokens={}
    for op in operations:
        snap=discover(api,manifest,root); wid=str(snap.workspace.get("workspace_id"))
        if op.action=="rename_workspace": api.mutate("workspace","rename",op.target,manifest["workspace"])
        elif op.action=="rename_tab": api.mutate("tab","rename",op.target,op.tab)
        elif op.action=="create_tab": tokens[f"new:{op.tab}:0"]=result_id(api.mutate("tab","create","--workspace",wid,"--cwd",str(root),"--label",op.tab,"--no-focus"),"root_pane","pane_id")
        elif op.action=="split":
            tab=next(t for t in snap.tabs if t.get("label")==op.tab); panes=[p for p in snap.panes if p.get("tab_id")==tab.get("tab_id")]
            tokens[op.target]=result_id(api.mutate("pane","split","--pane",str(panes[0]["pane_id"]),"--direction","right","--cwd",str(root),"--no-focus"),"pane","pane_id")
        elif op.action=="start":
            pane=tokens.get(op.target,op.target); api.mutate("agent","start",op.role,"--kind",manifest["agent_kind"],"--pane",pane)
        elif op.action=="initialize":
            agent=next((a for a in snap.agents if a.get("name")==op.role),None)
            if not agent or agent.get("agent_status") not in {"idle","done"}: raise WorkflowError(f"{op.role} is not settled for role initialization")
            version,prompt_sha,session=contract_identity(manifest,root,op.role,agent); previous=contracts.get(op.role,{})
            attempts=previous.get("attempts",0)+1 if contract_current(contracts,manifest,root,op.role,agent) else 1
            record={"workflow_version":version,"prompt_sha256":prompt_sha,"agent_session":session,"status":"attempting","attempts":attempts,"last_error":""}; contracts[op.role]=record; write_contracts(contracts)
            instruction=f"Read {root/'AGENTS.md'} and {root/'herdr/prompts'/(op.role+'.md')} completely, then wait for a coordinator task envelope."
            try: api.mutate("agent","prompt",op.role,instruction,"--wait","--timeout","120000")
            except WorkflowError as exc:
                record["status"]="failed"; record["last_error"]=str(exc)[:500]; write_contracts(contracts); raise
            record["status"]="delivered"; record["last_error"]=""; write_contracts(contracts)
        else: raise WorkflowError(f"unsupported operation: {op.action}")
        assert_transition(api,manifest,root,op,tokens)

def main():
    parser=argparse.ArgumentParser(description=__doc__); modes=parser.add_mutually_exclusive_group(required=True)
    for mode in ("validate-config","check","dry-run","setup","repair"): modes.add_argument("--"+mode,action="store_true")
    parser.add_argument("--settle-seconds",type=float,default=3.0); args=parser.parse_args()
    try:
        root=repo_root(); manifest=load_manifest(root)
        if args.validate_config: print("team.toml and role prompts are valid."); return 0
        binary=trusted_executable("herdr"); check_version(binary); check_integration(binary); api=Herdr(binary,manifest["session"],args.dry_run); identify_session(api,os.environ)
        with reconcile_lock():
            contracts=load_contracts(); snap=settle_restore(api,manifest,root,args.settle_seconds); ops,conflicts=plan(snap,manifest,root,contracts)
            if conflicts:
                print("Herdr team conflicts:",file=sys.stderr)
                for conflict in conflicts: print("- "+conflict,file=sys.stderr)
                return 1
            if args.check:
                drift=verify(snap,manifest,root,contracts)
                if drift:
                    for item in drift: print("- "+item,file=sys.stderr)
                    return 1
                print("Herdr team is healthy."); return 0
            for op in ops: print(f"Plan: {op.action} {op.role or op.tab or op.target}".rstrip())
            if args.dry_run:return 0
            apply_plan(api,manifest,root,ops,contracts); drift=verify(discover(api,manifest,root),manifest,root,load_contracts())
            if drift: raise WorkflowError("repair incomplete: "+"; ".join(drift))
            print("Herdr team is healthy."); return 0
    except (OSError,subprocess.TimeoutExpired,WorkflowError,tomllib.TOMLDecodeError,StopIteration) as exc:
        print(f"error: {exc}",file=sys.stderr); return 1

if __name__=="__main__": raise SystemExit(main())
