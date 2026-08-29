# Contributing

Thanks for helping improve this Fedora 44 Niri and Noctalia workstation setup.

## Before opening a pull request

1. Update `main` and create a focused branch. External contributors should do
   this in their fork; maintainers can create the branch in this repository.
2. Keep configuration portable across usernames and clone locations.
3. Never commit credentials, tokens, logs, diagnostic state, or other
   machine-specific private data.
4. Preserve unrelated configuration and avoid generated theme outputs.
5. Do not run the complete bootstrap only to validate a change; it installs
   packages and changes system services.

Read `AGENTS.md` for the repository's configuration ownership and desktop
conventions. Run the checks relevant to the files you changed. At minimum, run:

```bash
git diff --check
```

For bootstrap changes, also run:

```bash
bash -n bootstrap-fedora44-niri-v3.sh
./bootstrap-fedora44-niri-v3.sh --help >/dev/null
```

For other shell scripts, run `bash -n` on each changed script. If a documented
validator such as `niri`, `noctalia`, or a plugin linter is unavailable, mention
that in the pull request instead of installing it solely for validation.

## Pull requests

The `main` branch is protected: direct pushes, force pushes, and deletion are
blocked. All changes must be merged through a pull request, and all review
conversations must be resolved first. No approving review is currently required
because the repository has one maintainer.

Explain what changed, why it belongs in the shared configuration, how you
tested it, and any limitation that remains. Screenshots are helpful for visible
desktop changes but should not contain private information.
