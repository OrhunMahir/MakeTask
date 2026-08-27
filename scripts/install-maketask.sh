#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_path=$(CDPATH= cd -- "$script_dir/.." && pwd)
install_dir="${XDG_BIN_HOME:-$HOME/.local/bin}"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/maketask"
launcher="$install_dir/maketask"
mode="${1:-"--with-app"}"

case "$mode" in
    --with-app|--launcher-only) ;;
    --help|-h)
        printf 'Usage: %s [--with-app | --launcher-only]\n' "$0"
        exit 0
        ;;
    *)
        printf 'install-maketask.sh: unknown option %s\n' "$mode" >&2
        exit 1
        ;;
esac

mkdir -p "$install_dir" "$config_dir"
/usr/bin/install -m 755 "$script_dir/maketask" "$launcher"
printf '%s\n' "$repo_path" > "$config_dir/repo-path"

printf 'Installed launcher at %s\n' "$launcher"
printf 'Configured repository at %s\n' "$repo_path"

case ":$PATH:" in
    *":$install_dir:"*) ;;
    *)
        printf '\n%s is not currently in PATH. Add this line to your shell profile:\n' "$install_dir"
        printf 'export PATH="%s:$PATH"\n' "$install_dir"
        ;;
esac

if [ "$mode" = "--with-app" ]; then
    "$launcher" --install-app
    "$launcher"
else
    printf '\nLauncher-only installation complete. Use maketask --dev, or run maketask --install-app once.\n'
fi
