# Persistent dotfiles Herdr team

This directory reproducibly defines a dedicated Herdr 0.8.2 session named
`fedora-niri-dotfiles`. Herdr owns the live persistent state; this repository
owns only the desired topology, role contracts, recovery tooling, and operating
documentation.

## Topology and authority

`team.toml` is canonical. It declares one `Dotfiles Team` workspace:

| Tab | Roles |
| --- | --- |
| Build | `coordinator`, `implementation`, `integration` |
| Review | `validation`, `security`, `release` |

Each tab contains three Codex agents, below Herdr's four-agent-per-tab limit.
The prompts constrain authority: the coordinator assigns work; implementation
is the normal writer; integration freezes a coherent commit; validation and
security review that commit; release audits readiness. No role may silently
push, open a PR, merge, run the workstation bootstrap, or mutate live desktop
configuration.

## Prerequisites and restore

- Herdr 0.8.2 and Codex are installed.
- `herdr integration status` reports `codex: current`.
- Codex hooks are enabled as documented by Herdr.
- Herdr's `session.resume_agents_on_restore` remains enabled (the default).

If integration is missing or outdated, inspect the change and explicitly run:

```bash
herdr integration install codex
```

Inspect the documented default with `herdr --default-config`. If your existing
Herdr configuration explicitly disables restore, review and manually set this
in `~/.config/herdr/config.toml`:

```toml
[session]
resume_agents_on_restore = true
```

The setup tool checks that the Codex integration is current but deliberately
does not install it or overwrite this user-owned configuration.

The repository never edits `~/.config/herdr/config.toml`, `~/.codex`, or
Herdr's `session.json`. Do not copy those files into Git. Prompt changes apply
only when a role is newly started or explicitly prompted; they do not rewrite a
running conversation.

Client detach/reattach preserves running processes. A server restart restores
Herdr's recorded layout and can resume Codex conversations when the official
integration supplied a valid session reference. Terminal scrollback is not
durable task memory. If state is missing, the tracked setup tool can recreate
the topology, but it cannot reconstruct a lost conversation.

## Normal use and first setup

The main bootstrap already links the tracked `.zshrc`; there are no additional
live links, services, or systemd units. After this change is installed, reload
zsh. From this canonical checkout or a descendant, a zero-argument invocation
selects the dedicated session:

```zsh
exec zsh
cd /path/to/this/checkout
herdr
```

Arguments always pass directly to upstream Herdr. Plain `herdr` outside this
checkout also retains the upstream default-session behavior. A zero-argument
call from inside any Herdr pane is refused to prevent nested attachment.

On the first attach, use a shell pane inside the new named session:

```bash
herdr/bootstrap-team.sh --validate-config
herdr/bootstrap-team.sh --dry-run
herdr/bootstrap-team.sh --setup
herdr/bootstrap-team.sh --check
```

`--setup` and `--repair` are the same additive, idempotent reconciliation path.
They read all opaque IDs from Herdr JSON, create in the background with the
repository root as cwd, and start a missing role only in a verified empty shell.
They rename only the sole pristine initial workspace/tab during adoption and
never close, stop, replace, rename, or send keys to an existing agent.
Duplicate labels, wrong cwd/kind/tab,
unexpected occupied panes, extra named agents, unknown agents, or an unsupported
version fail closed for manual inspection. Blocked and working agents are
preserved as valid live roles and are never replaced. Normal attachment does
not run repair, avoiding races with native session restore.

Herdr 0.8.2 does not inject `HERDR_SESSION` into panes. The controller does not
depend on it: it requires the inherited socket/pane IDs, maps the canonical
socket through `herdr session list --json`, and confirms `pane current
--current` belongs to the running dedicated session before inspection. A fresh
named session begins with one workspace, tab, and shell pane. Setup adopts that
workspace only when it is the sole workspace, uses the canonical repository
cwd, contains exactly one empty shell, and has no agents. Any other unexpected
workspace fails closed; setup never creates a hidden second workspace.

Before mutation, the controller takes one coherent discovery snapshot, waits up
to three seconds for panes carrying native agent-session metadata to settle,
and computes the complete immutable plan. Any conflict cancels the whole plan
with zero writes. A still-unrecognized session-bearing pane is reported and
preserved. An empty fallback shell without restore metadata can be assigned a
new role during an explicit repair; this starts a new conversation and cannot
recover the lost one. Each applied operation is rediscovered and checked before
the next, so an interrupted run can be retried additively.

Role-contract delivery is a separate durable reconciliation phase. A private
`role-contracts.json` records the workflow version, prompt SHA-256, native agent
session identity, delivery state, and attempt count. A retained name after a
failed/not-ready start is never restarted. An idle uninitialized role is
prompted independently; one failed or interrupted delivery gets exactly one
retry, while a second failure or a blocked uninitialized role is reported for
user intervention. Successful delivery is not repeated until the prompt,
workflow version, or native agent session changes.

Useful read-only inspection:

```bash
herdr --version
herdr integration status
herdr session list --json
herdr workspace list
herdr agent list
```

Use `herdr agent get ROLE` when a role is blocked. Never answer a blocked UI
automatically. `idle` and `done` are settled, `working` is active, `blocked`
needs a user decision, and `unknown` does not prove completion.

## Durable handoffs

`handoff.sh` provides the deliberately small persistence layer needed for role
correctness and restart recovery. It stores a schema-validated lifecycle ledger
and bounded immutable handoff attempts outside Git under
`${XDG_STATE_HOME:-$HOME/.local/state}/fedora-niri-dotfiles/herdr/tasks/`, with
private permissions, a lock, atomic replacement, and SHA-256 output:

```bash
head=$(git rev-parse HEAD)
herdr/handoff.sh init task-123 "$head"
herdr/handoff.sh transition task-123 intake triaged coordinator "$head"
herdr/handoff.sh transition task-123 triaged assigned_implementation implementation "$head"
herdr/handoff.sh put task-123 implementation 1 "$head" /path/to/handoff.md
herdr/handoff.sh ack task-123 implementation 1 SHA256_FROM_PUT
herdr/handoff.sh recover task-123 "$PWD"
```

Use repository-relative paths and commit IDs in handoffs. Never store secrets,
credentials, raw terminal transcripts, or unbounded logs. A coordinator task
prompt should carry `TASK`, `STATE`, `ROLE`, `REPO_ROOT`, `BASE/HEAD`, `SCOPE`,
`PROHIBITED`, `INPUT_ARTIFACTS` with hashes, `ACCEPTANCE`, and `RETURN`.
The ledger records the state, assigned role, attempt, base/current commit,
latest immutable artifact, and acknowledgement. Transitions reject stale
expected states; `put` rejects assignment/attempt/head mismatches and existing
attempt paths; `recover` verifies Git HEAD and artifact hashes before resuming.
This intentionally does not schedule agents or publish Git changes: the
coordinator remains responsible for prompts and state transitions.

Blocking is a structured overlay, not a free-standing shortcut. Entry records
the preserved state, current owner, required actor, and required action:

```bash
herdr/handoff.sh transition task-123 implementing blocked implementation "$head" \
  --owner implementation --required-actor user \
  --required-action 'approve network access'
herdr/handoff.sh transition task-123 blocked implementing implementation "$head" --by user
```

Resume is legal only to `blocked_from` with the preserved owner. The coordinator
may instead route to cancellation or the matching implementation/integration
rework state. Direct blocked-to-release/complete jumps and stale resumes fail.

## Recovery, update, and rollback

After a client loss, run plain `herdr` from the checkout and allow restore to
settle. After a server restart, inspect `herdr agent list` before considering
repair. If a Codex pane fell back to a shell, verify the integration and decide
explicitly whether losing its old conversation is acceptable. Run `--check`,
then `--dry-run`, then `--repair` only for additive recovery.

Never stop/delete `default`, `fedora-niri-dotfiles`, or the existing
`Dotfiles Team` as an automated repair. Duplicate or corrupt state requires a
user-reviewed manual recovery using IDs freshly obtained from JSON. Preserve
the session directory before any destructive recovery.

Updates are repository updates through the protected-branch workflow. Validate
the new manifest first; existing agents keep their current contracts until they
are safely restarted. Roll back tracked configuration with a normal revert PR
or return to the prior repository revision—never rewrite `main` history.

To uninstall routing, revert/remove the three-line `.zshrc` source block and
the tracked `herdr/` directory through a reviewed commit. This intentionally
leaves Herdr itself, credentials, unrelated sessions, the dedicated live
session, and XDG task state untouched. Remove XDG task state or stop/delete the
dedicated session only as a separate explicit action after confirming no work
is needed.

## Validation

Run `herdr/tests/run.sh`. Its evolving fake Herdr server covers fresh adoption,
no-op rerun, additive and interrupted repair, restore settling, blocked/working
preservation, durable role initialization and its single retry, retained
not-ready names, conflict zero-mutation, malformed/error responses, and absent
`HERDR_SESSION`. Shell tests cover symlinked `.zshrc`, spaces, alternate
repositories, argument forwarding, and nested launch. It never touches a live
session. A uniquely named integration session may be
tested manually later, but never stop/delete the live default or Dotfiles Team
session and never run the full Fedora bootstrap merely to validate this feature.
