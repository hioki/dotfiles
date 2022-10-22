#!/bin/bash

cd "$(dirname "$0")/../" || return

read -r -p "Create symbolic link to $HOME/.git_template ? [Y/n]: " yn
case "$yn" in
[yY]*) ;;
*)
    echo "cancelled."
    exit 0
    ;;
esac

ln -s "$(pwd)"/.git_template "$HOME/"

echo "done."
