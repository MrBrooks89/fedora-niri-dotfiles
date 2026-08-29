#!/usr/bin/env python3
"""Schema-validated task ledger with immutable handoff attempts."""
import argparse, fcntl, hashlib, json, os, re, subprocess, sys, tempfile
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path
ROLES={"coordinator","implementation","integration","validation","security","release"}
STATES={"intake","triaged","assigned_implementation","implementing","integration_review","validation","security_review","release_review","ready_for_user","blocked","rework_implementation","rework_integration","complete","cancelled"}
TRANSITIONS={"intake":{"triaged","blocked","cancelled"},"triaged":{"assigned_implementation","blocked","cancelled"},"assigned_implementation":{"implementing","blocked","cancelled"},"implementing":{"integration_review","blocked","cancelled"},"integration_review":{"validation","rework_implementation","blocked","cancelled"},"validation":{"security_review","rework_implementation","rework_integration","blocked","cancelled"},"security_review":{"release_review","rework_implementation","rework_integration","blocked","cancelled"},"release_review":{"ready_for_user","rework_implementation","rework_integration","blocked","cancelled"},"ready_for_user":{"complete","blocked","cancelled"},"rework_implementation":{"assigned_implementation","cancelled"},"rework_integration":{"integration_review","cancelled"},"blocked":STATES-{"intake"},"complete":set(),"cancelled":set()}
ID_RE=re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$"); SHA_RE=re.compile(r"^[0-9a-f]{40,64}$")
def now(): return datetime.now(timezone.utc).isoformat()
def state_root():
    path=Path(os.environ.get("XDG_STATE_HOME",Path.home()/".local/state"))/"fedora-niri-dotfiles/herdr"; path.mkdir(mode=0o700,parents=True,exist_ok=True)
    if path.is_symlink() or path.stat().st_uid!=os.getuid(): raise ValueError("state directory has unsafe ownership or symlink")
    path.chmod(0o700); return path
@contextmanager
def locked(base):
    lock=base/".task.lock"
    with lock.open("a+") as handle: os.chmod(lock,0o600); fcntl.flock(handle,fcntl.LOCK_EX); yield
def directory(base,task):
    if not ID_RE.fullmatch(task): raise ValueError("invalid task ID")
    path=base/"tasks"/task
    if path.exists() and (path.is_symlink() or path.stat().st_uid!=os.getuid()): raise ValueError("task directory has unsafe ownership or symlink")
    return path
def validate(data,task):
    keys={"schema_version","task","state","assigned_role","attempt","base_head","current_head","created_at","updated_at","blocking_reason","last_handoff","acknowledged"}
    if not isinstance(data,dict) or set(data)!=keys or data["schema_version"]!=1 or data["task"]!=task: raise ValueError("invalid task schema")
    if data["state"] not in STATES or data["assigned_role"] not in ROLES or type(data["attempt"]) is not int or data["attempt"]<0: raise ValueError("invalid lifecycle fields")
    if not all(isinstance(data[k],str) for k in ("base_head","current_head","created_at","updated_at","blocking_reason")): raise ValueError("invalid scalar fields")
    if any(data[k] is not None and not isinstance(data[k],dict) for k in ("last_handoff","acknowledged")): raise ValueError("invalid handoff metadata")
    if data["last_handoff"] is not None and (set(data["last_handoff"])!={"role","attempt","head","path","sha256"} or not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}-[0-9]+\.md",str(data["last_handoff"].get("path","")))): raise ValueError("invalid latest handoff schema")
    if data["acknowledged"] is not None and set(data["acknowledged"])!={"role","attempt","head","path","sha256","acknowledged_at"}: raise ValueError("invalid acknowledgement schema")
    return data
def load(path,task): return validate(json.loads((path/"task.json").read_text()),task)
def write(path,data):
    fd,name=tempfile.mkstemp(prefix=".task.",dir=path); os.close(fd); temp=Path(name)
    try: temp.write_text(json.dumps(data,indent=2,sort_keys=True)+"\n"); temp.chmod(0o600); os.replace(temp,path/"task.json")
    finally:
        if temp.exists(): temp.unlink()
def digest(path):
    value=hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda:handle.read(65536),b""): value.update(block)
    return value.hexdigest()
def main():
    parser=argparse.ArgumentParser(); sub=parser.add_subparsers(dest="command",required=True)
    p=sub.add_parser("init"); p.add_argument("task"); p.add_argument("base_head")
    p=sub.add_parser("show"); p.add_argument("task")
    p=sub.add_parser("transition"); p.add_argument("task"); p.add_argument("expected"); p.add_argument("next"); p.add_argument("role"); p.add_argument("head"); p.add_argument("--reason",default="")
    p=sub.add_parser("put"); p.add_argument("task"); p.add_argument("role"); p.add_argument("attempt",type=int); p.add_argument("head"); p.add_argument("source")
    p=sub.add_parser("ack"); p.add_argument("task"); p.add_argument("role"); p.add_argument("attempt",type=int); p.add_argument("sha256")
    p=sub.add_parser("recover"); p.add_argument("task"); p.add_argument("repo")
    args=parser.parse_args(); base=state_root(); path=directory(base,args.task)
    with locked(base):
      if args.command=="init":
        if not SHA_RE.fullmatch(args.base_head): raise ValueError("base_head must be a Git object ID")
        path.mkdir(parents=True,exist_ok=False); (path/"handoffs").mkdir(); path.chmod(0o700); (path/"handoffs").chmod(0o700); stamp=now()
        write(path,{"schema_version":1,"task":args.task,"state":"intake","assigned_role":"coordinator","attempt":0,"base_head":args.base_head,"current_head":args.base_head,"created_at":stamp,"updated_at":stamp,"blocking_reason":"","last_handoff":None,"acknowledged":None}); print(path); return
      data=load(path,args.task)
      if args.command=="show": print(json.dumps(data,indent=2,sort_keys=True)); return
      if args.command=="transition":
        if data["state"]!=args.expected or args.next not in TRANSITIONS[data["state"]]: raise ValueError("invalid or stale state transition")
        if args.role not in ROLES or not SHA_RE.fullmatch(args.head): raise ValueError("invalid role or head")
        if args.next=="blocked" and not args.reason.strip(): raise ValueError("blocked transition requires --reason")
        if args.role!=data["assigned_role"]: data["attempt"]+=1
        data.update(state=args.next,assigned_role=args.role,current_head=args.head,blocking_reason=args.reason.strip() if args.next=="blocked" else "",updated_at=now()); write(path,data); return
      if args.command=="put":
        source=Path(args.source)
        if (args.role,args.attempt,args.head)!=(data["assigned_role"],data["attempt"],data["current_head"]): raise ValueError("handoff does not match current assignment")
        if not source.is_file() or source.is_symlink() or source.stat().st_nlink!=1 or source.stat().st_uid!=os.getuid() or source.stat().st_size>65536: raise ValueError("handoff must be a private regular file at most 64 KiB")
        target=path/"handoffs"/f"{args.role}-{args.attempt}.md"
        if target.exists(): raise ValueError("handoff attempt is immutable")
        fd,name=tempfile.mkstemp(prefix=".handoff.",dir=target.parent); os.close(fd); temp=Path(name)
        try: temp.write_bytes(source.read_bytes()); temp.chmod(0o600); os.replace(temp,target)
        finally:
            if temp.exists(): temp.unlink()
        sha=digest(target); data["last_handoff"]={"role":args.role,"attempt":args.attempt,"head":args.head,"path":target.name,"sha256":sha}; data["acknowledged"]=None; data["updated_at"]=now(); write(path,data); print(f"{sha}  {target}"); return
      if args.command=="ack":
        handoff=data["last_handoff"]
        if not handoff or (args.role,args.attempt,args.sha256)!=(handoff["role"],handoff["attempt"],handoff["sha256"]): raise ValueError("acknowledgement does not match latest handoff")
        if digest(path/"handoffs"/handoff["path"])!=args.sha256: raise ValueError("handoff hash mismatch")
        data["acknowledged"]={**handoff,"acknowledged_at":now()}; data["updated_at"]=now(); write(path,data); return
      if args.command=="recover":
        repo=Path(args.repo).resolve(); proc=subprocess.run(["git","-C",str(repo),"rev-parse","HEAD"],text=True,stdout=subprocess.PIPE)
        if proc.returncode or proc.stdout.strip()!=data["current_head"]: raise ValueError("Git HEAD does not match durable task state")
        if data["last_handoff"]:
            handoff=data["last_handoff"]; target=path/"handoffs"/handoff["path"]
            if not target.is_file() or digest(target)!=handoff["sha256"]: raise ValueError("latest handoff is missing or changed")
            if data["acknowledged"] and data["acknowledged"]["sha256"]!=handoff["sha256"]: raise ValueError("acknowledgement is stale")
        print(json.dumps(data,sort_keys=True)); return
if __name__=="__main__":
  try: main()
  except (OSError,ValueError,json.JSONDecodeError) as exc: print(f"error: {exc}",file=sys.stderr); raise SystemExit(1)
