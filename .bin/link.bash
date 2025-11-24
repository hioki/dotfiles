#!/bin/bash

cd "$(dirname "$0")/../" || return

dotfiles=()
while IFS='' read -r line; do
    dotfiles+=("$line")
done < <(find . -maxdepth 1 -type f -name ".*" | \sed -e 's,^\./,,')

echo "Create symbolic link to ${HOME}/* ?"
echo "--------------------------------------------------------------------------------"
for dotfile in "${dotfiles[@]}"; do
    echo "$dotfile"
done
echo "--------------------------------------------------------------------------------"

read -r -p "[Y/n]: " yn
case "$yn" in
[yY]*) ;;
*)
    echo "cancelled."
    exit 0
    ;;
esac

echo "creating symbolic link..."

for dotfile in "${dotfiles[@]}"; do
    ln -sf "$(pwd)/$dotfile" "$HOME/$dotfile"
done

echo "done."
