#!/usr/bin/env bash

resolve_github_repo() {
    local repo_dir="$1"
    local remote
    remote="$(git -C "$repo_dir" remote get-url origin 2>/dev/null)" || return 1

    case "$remote" in
        https://github.com/*)
            remote="${remote#https://github.com/}"
            ;;
        git@github.com:*)
            remote="${remote#git@github.com:}"
            ;;
        ssh://git@github.com/*)
            remote="${remote#ssh://git@github.com/}"
            ;;
        *) return 1 ;;
    esac

    remote="${remote%.git}"
    [[ "$remote" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || return 1
    printf '%s\n' "$remote"
}
