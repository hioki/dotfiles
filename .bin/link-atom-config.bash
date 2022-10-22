#!/bin/bash

cd "$(dirname "$0")/../" || return

read -r -p "Create symbolic link to $HOME/.atom/* ? [Y/n]: " yn
case "$yn" in
[yY]*) ;;
*)
    echo "cancelled."
    exit 0
    ;;
esac

mkdir -p "$HOME/.atom"
ln -s "$(pwd)"/.atom/* "$HOME/.atom/"

echo "done."
