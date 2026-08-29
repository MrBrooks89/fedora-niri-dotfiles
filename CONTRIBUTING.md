# Contributing

Thanks for helping improve this Fedora 44 Niri and Noctalia workstation setup.

## Before opening a pull request

1. Fork the repository and create a focused branch from `main`.
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

Explain what changed, why it belongs in the shared configuration, how you
tested it, and any limitation that remains. Screenshots are helpful for visible
desktop changes but should not contain private information.
