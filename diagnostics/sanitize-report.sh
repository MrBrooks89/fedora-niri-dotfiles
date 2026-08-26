#!/usr/bin/env bash
set -Eeuo pipefail

# Keep diagnostic evidence useful while removing common personal and secret data.
# Input is accepted only on stdin so this script never reads arbitrary files.
sed -E \
    -e "s|$HOME|~|g" \
    -e 's/([[:alnum:]_.+-]+)@([[:alnum:].-]+\.[[:alpha:]]{2,})/<email>/g' \
    -e 's/([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}/<mac-address>/g' \
    -e 's/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<ip-address>/g' \
    -e 's/(authorization[[:space:]]*:[[:space:]]*).*$/\1<redacted>/Ig' \
    -e 's/((password|passwd|token|secret|api[_-]?key|cookie|authorization)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1<redacted>/Ig' \
    -e 's/(Bearer[[:space:]]+)[[:alnum:]_.~+\/-]+/\1<redacted>/Ig' \
    -e 's/\b(gh[pousr]_[[:alnum:]_]{20,}|sk-[[:alnum:]_-]{20,})\b/<redacted-token>/g'
