#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
PYTHONDONTWRITEBYTECODE=1 python3 "$ROOT/herdr/tests/test_team.py"
"$ROOT/herdr/tests/test-shell-routing.sh"
"$ROOT/herdr/tests/test-handoff.sh"
