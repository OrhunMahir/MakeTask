#!/bin/sh

set -eu

install_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/maketask"
launcher="$install_dir/maketask"
remove_app=false

case "${1:-}" in
    "") ;;
    --with-app) remove_app=true ;;
    --help|-h)
        printf 'Usage: %s [--with-app]\n' "$0"
        exit 0
        ;;
    *)
        printf 'uninstall-maketask.sh: unknown option %s\n' "$1" >&2
        exit 1
        ;;
esac

rm -f "$launcher" "$config_dir/repo-path"
rmdir "$config_dir" 2>/dev/null || true
printf 'Removed the MakeTask terminal launcher and repository configuration.\n'

if [ "$remove_app" = true ]; then
    user_app="$HOME/Applications/MakeTask.app"
    if [ -d "$user_app" ]; then
        rm -rf "$user_app"
        printf 'Removed %s\n' "$user_app"
    fi
fi
