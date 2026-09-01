#!/bin/bash
#
# shrink-recording.bash を PATH に通す。

cd "$(dirname "$0")/../" || return

read -r -p "Create symbolic link to $HOME/.local/bin/shrink-recording ? [Y/n]: " yn
case "$yn" in
[yY]*) ;;
*)
    echo "cancelled."
    exit 0
    ;;
esac

mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/.bin/shrink-recording.bash" "$HOME/.local/bin/shrink-recording"

echo "done."
