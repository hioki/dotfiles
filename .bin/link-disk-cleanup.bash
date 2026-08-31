#!/bin/bash
#
# disk-cleanup.bash を PATH に通し、月次実行の launchd エージェントを登録する。

cd "$(dirname "$0")/../" || return

read -r -p "Install disk-cleanup and its monthly launchd agent ? [Y/n]: " yn
case "$yn" in
[yY]*) ;;
*)
    echo "cancelled."
    exit 0
    ;;
esac

mkdir -p "$HOME/.local/bin" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
ln -sf "$(pwd)/.bin/disk-cleanup.bash" "$HOME/.local/bin/disk-cleanup"

case "$(uname -s)" in
Darwin)
    plist="$HOME/Library/LaunchAgents/com.hioki.disk-cleanup.plist"
    ln -sf "$(pwd)/launchd/com.hioki.disk-cleanup.plist" "$plist"
    # 既に読み込まれている場合に備えて一度外してから入れ直す。
    launchctl bootout "gui/$(id -u)/com.hioki.disk-cleanup" 2>/dev/null
    launchctl bootstrap "gui/$(id -u)" "$plist"
    ;;
*)
    echo "launchd agent is macOS only; skipped."
    ;;
esac

echo "done."
