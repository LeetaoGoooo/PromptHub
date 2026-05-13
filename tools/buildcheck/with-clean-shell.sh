#!/bin/zsh

set -euo pipefail

if (( $# == 0 )); then
    echo "usage: $0 <command> [args...]" >&2
    exit 64
fi

script_dir=${0:A:h}
repo_root=${script_dir:h:h}
developer_dir=${DEVELOPER_DIR:-$(xcode-select -p)}

/usr/bin/env -i \
    HOME="$HOME" \
    USER="${USER:-}" \
    LOGNAME="${LOGNAME:-}" \
    TMPDIR="${TMPDIR:-/tmp}" \
    LANG="${LANG:-en_US.UTF-8}" \
    LC_CTYPE="${LC_CTYPE:-en_US.UTF-8}" \
    PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    DEVELOPER_DIR="$developer_dir" \
    /bin/zsh -dfs -- "$repo_root" "$@" <<'EOF'
repo_root="$1"
shift

cd "$repo_root"
"$@"
EOF