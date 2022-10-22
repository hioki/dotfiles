#!/bin/bash

cd "$(dirname "$0")/../" || return

read -r -p "Create symbolic link to $HOME/.cargo/config.toml ? [Y/n]: " yn
case "$yn" in
[yY]*) ;;
*)
    echo "cancelled."
    exit 0
    ;;
esac

mkdir -p "$HOME/.cargo"
ln -s "$(pwd)/.cargo/config.toml" "$HOME/.cargo/config.toml"

echo "done."
