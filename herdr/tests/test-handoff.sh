#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
TMP="$(mktemp -d)"; trap 'rm -rf -- "$TMP"' EXIT
export XDG_STATE_HOME="$TMP/state"
head="$(git -C "$ROOT" rev-parse HEAD)"
printf '# immutable handoff\n' >"$TMP/input.md"
task_dir="$($ROOT/herdr/handoff.sh init task-123 "$head")"
$ROOT/herdr/handoff.sh transition task-123 intake triaged coordinator "$head"
$ROOT/herdr/handoff.sh transition task-123 triaged assigned_implementation implementation "$head"
result="$($ROOT/herdr/handoff.sh put task-123 implementation 1 "$head" "$TMP/input.md")"
sha="${result%% *}"
$ROOT/herdr/handoff.sh ack task-123 implementation 1 "$sha"
$ROOT/herdr/handoff.sh recover task-123 "$ROOT" >/dev/null
[[ "$(stat -c %a "$task_dir")" == 700 ]]
[[ "$(stat -c %a "$task_dir/handoffs/implementation-1.md")" == 600 ]]
if $ROOT/herdr/handoff.sh put task-123 implementation 1 "$head" "$TMP/input.md" >/dev/null 2>&1; then echo 'immutable overwrite accepted' >&2; exit 1; fi
if $ROOT/herdr/handoff.sh transition task-123 intake complete coordinator "$head" >/dev/null 2>&1; then echo 'stale transition accepted' >&2; exit 1; fi
ln -s "$TMP/input.md" "$TMP/link.md"
if $ROOT/herdr/handoff.sh put task-123 implementation 1 "$head" "$TMP/link.md" >/dev/null 2>&1; then echo 'symlink accepted' >&2; exit 1; fi

$ROOT/herdr/handoff.sh init blocked-task "$head" >/dev/null
if $ROOT/herdr/handoff.sh transition blocked-task intake blocked coordinator "$head" >/dev/null 2>&1; then echo 'reasonless block accepted' >&2; exit 1; fi
$ROOT/herdr/handoff.sh transition blocked-task intake blocked coordinator "$head" --reason 'waiting for user authority'

python3 -c 'import json,sys; p=sys.argv[1]; d=json.load(open(p)); d["schema_version"]=99; open(p,"w").write(json.dumps(d))' "$task_dir/task.json"
if $ROOT/herdr/handoff.sh show task-123 >/dev/null 2>&1; then echo 'invalid schema accepted' >&2; exit 1; fi
