#!/usr/bin/env bash
#
# disk-cleanup.bash — 再生成可能な派生物だけを削除してディスクを空ける。
#
# 対象は「コマンド一発で再生成できるもの」に限る。ソース、設定、鍵、~/Keep
# には一切触れない。target ディレクトリは同階層に Cargo.toml があるものだけを
# 対象とし、名前が target というだけのディレクトリは無視する。
#
# 既定は dry-run。実際に削除するには --apply を明示的に渡す。
#
#   disk-cleanup.bash                  削除見込みを表示するだけ
#   disk-cleanup.bash --apply          実行する
#   disk-cleanup.bash --apply --age 30 target の保持日数を変える（既定 90 日）
#
# launchd から月次で呼ぶ場合も --apply が必要。
#
set -uo pipefail

# launchd や cron から呼ばれると PATH が /usr/bin:/bin だけになり、brew や
# cargo-sweep を見つけられない。各ツールの標準的な配置を補っておく。
PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.local/bin:$PATH"
export PATH

APPLY=0
AGE=90
REPO_ROOT="${DISK_CLEANUP_REPO_ROOT:-$HOME/.rhq}"

while [ $# -gt 0 ]; do
    case "$1" in
    --apply) APPLY=1 ;;
    --age)
        AGE="${2:?--age には日数が必要}"
        shift
        ;;
    -h | --help)
        awk 'NR >= 3 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
        exit 0
        ;;
    *)
        echo "不明な引数: $1" >&2
        exit 2
        ;;
    esac
    shift
done

# --------------------------------------------------------------------------
# 表示ヘルパ
# --------------------------------------------------------------------------

TOTAL_KB=0

section() { printf '\n== %s\n' "$*"; }

human() {
    awk -v k="$1" 'BEGIN {
        split("KB MB GB TB", u, " "); i = 1
        while (k >= 1024 && i < 4) { k /= 1024; i++ }
        printf "%.1f %s", k, u[i]
    }'
}

size_kb() {
    [ -e "$1" ] || { echo 0; return; }
    du -sk "$1" 2>/dev/null | awk 'END {print $1 + 0}'
}

# 集計に加えて 1 行表示する。実削除はしない（呼び出し側が行う）。
account() { # account <kb> <ラベル>
    [ "$1" -gt 0 ] || return 1
    TOTAL_KB=$((TOTAL_KB + $1))
    printf '  %10s  %s\n' "$(human "$1")" "$2"
}

# パスを丸ごと消す。--apply が無ければサイズを数えるだけ。
purge() { # purge <パス> [ラベル]
    local path="$1" kb
    kb=$(size_kb "$path")
    account "$kb" "${2:-$path}" || return 0
    [ "$APPLY" -eq 1 ] && rm -rf -- "$path"
    return 0
}

# 外部コマンドで消す。dry-run では対象ディレクトリのサイズを見込みとして出す。
purge_with() { # purge_with <サイズ計測パス> <ラベル> <コマンド...>
    local path="$1" label="$2" kb
    shift 2
    command -v "$1" >/dev/null 2>&1 || return 0
    kb=$(size_kb "$path")
    account "$kb" "$label" || return 0
    [ "$APPLY" -eq 1 ] && "$@" >/dev/null 2>&1
    return 0
}

# --------------------------------------------------------------------------
# 層 A: パッケージマネージャのキャッシュ
# --------------------------------------------------------------------------

section "パッケージキャッシュ"

purge_with "$(brew --cache 2>/dev/null || echo /nonexistent)" "Homebrew" \
    brew cleanup -s --prune=all
purge_with "$HOME/.npm/_cacache" "npm" npm cache clean --force
purge "$HOME/.npm/_npx" "npx 一時パッケージ"
purge_with "$HOME/.cache/uv" "uv" uv cache clean
purge_with "$(go env GOMODCACHE 2>/dev/null || echo /nonexistent)" "Go module cache" \
    go clean -modcache
purge "$HOME/Library/Caches/go-build" "Go build cache"
purge "$HOME/Library/Caches/pnpm" "pnpm"
purge "$HOME/Library/Caches/Yarn" "Yarn"
purge "$HOME/Library/Caches/pip" "pip"

# --------------------------------------------------------------------------
# 層 A: Docker / Xcode
# --------------------------------------------------------------------------

section "Docker"

# Docker Desktop の CLI は PATH に無いことがある。
DOCKER=$(command -v docker || echo /Applications/Docker.app/Contents/Resources/bin/docker)
if [ -x "$DOCKER" ] && "$DOCKER" info >/dev/null 2>&1; then
    # 名前付きボリュームは prune の対象外にする。キャッシュとは限らず、
    # データベースの実体が入っていることがあるため無人実行では消さない。
    reclaimable=$("$DOCKER" system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null |
        awk -F'|' '$1 != "Local Volumes" && match($2, /^[0-9.]+/) {
                       v = substr($2, 1, RLENGTH) + 0; u = substr($2, RLENGTH + 1)
                       if (u ~ /^[GT]B/) v *= 1024 * 1024
                       else if (u ~ /^MB/) v *= 1024
                       else if (u !~ /^[kK]B/) v /= 1024
                       s += v
                   } END { printf "%d", s + 0 }')
    account "${reclaimable:-0}" "未使用イメージ・ビルドキャッシュ"
    [ "$APPLY" -eq 1 ] && "$DOCKER" system prune -a -f >/dev/null 2>&1

    dangling=$("$DOCKER" volume ls -qf dangling=true 2>/dev/null)
    if [ -n "$dangling" ]; then
        echo "  未使用の名前付きボリュームあり（中身を確認して docker volume rm で削除）:"
        printf '%s\n' "$dangling" | sed 's/^/    /'
    fi
else
    echo "  (Docker が起動していないためスキップ)"
fi

section "Xcode / iOS"

purge "$HOME/Library/Developer/Xcode/DerivedData" "DerivedData"
purge "$HOME/Library/Developer/Xcode/iOS DeviceSupport" "iOS DeviceSupport（端末接続時に再生成）"
purge "$HOME/Library/Developer/Xcode/watchOS DeviceSupport" "watchOS DeviceSupport"
purge "$HOME/Library/iTunes/iPhone Software Updates" "iPhone IPSW"
purge "$HOME/Library/iTunes/iPad Software Updates" "iPad IPSW"

# --------------------------------------------------------------------------
# 層 A: Rust のビルド成果物
# --------------------------------------------------------------------------

section "Rust ビルド成果物"

# 集約先（.cargo/config.toml の build.target-dir と揃えること）は cargo-sweep
# で古い成果物だけを間引く。cargo-sweep はプロジェクトルートから target を
# 辿るため、集約先ではなくリポジトリ群を渡す。
SHARED_TARGET="${CARGO_TARGET_DIR:-$HOME/.cache/cargo-target}"
if command -v cargo-sweep >/dev/null 2>&1 && [ -d "$REPO_ROOT" ]; then
    if [ "$APPLY" -eq 1 ]; then
        before=$(size_kb "$SHARED_TARGET")
        cargo sweep --recursive --time "$AGE" "$REPO_ROOT" >/dev/null 2>&1
        account $((before - $(size_kb "$SHARED_TARGET"))) "共有 target を cargo-sweep（$AGE 日）"
    else
        cargo sweep --recursive --time "$AGE" --dry-run "$REPO_ROOT" 2>&1 |
            sed -n 's/^\[INFO\] Would clean:/  cargo-sweep 見込み:/p'
    fi
elif [ -d "$SHARED_TARGET" ]; then
    printf '  %10s  %s\n' "-" "cargo-sweep 未インストールのため共有 target は手つかず"
fi

# リポジトリ直下に残っている target を、AGE 日以上触られていなければ消す。
# CARGO_TARGET_DIR 集約後はこれらは参照されないので、自然に期限切れで消える。
REF=$(mktemp -t disk-cleanup-ref)
trap 'rm -f "$REF"' EXIT
if ! touch -t "$(date -v-"${AGE}"d '+%Y%m%d%H%M' 2>/dev/null)" "$REF" 2>/dev/null; then
    touch -d "-${AGE} days" "$REF" # GNU date 系のフォールバック
fi

if [ -d "$REPO_ROOT" ]; then
    while IFS= read -r target; do
        # 名前が target というだけのディレクトリを消さないための確認。
        [ -f "${target%/target}/Cargo.toml" ] || continue
        # ビルドプロファイルのディレクトリに基準日より新しいものがあれば現役と
        # みなす。.rustc_info.json や tmp は cargo や rust-analyzer が起動する
        # だけで更新されるため、判定から除外する。
        [ -z "$(find "$target" -mindepth 1 -maxdepth 1 -newer "$REF" \
            ! -name '.rustc_info.json' ! -name 'CACHEDIR.TAG' \
            ! -name '.cargo-lock' ! -name 'tmp' -print 2>/dev/null | head -1)" ] || continue
        purge "$target" "${target#"$REPO_ROOT"/}"
    done < <(find "$REPO_ROOT" -type d -name target -prune 2>/dev/null)
fi

# --------------------------------------------------------------------------
# 結果
# --------------------------------------------------------------------------

section "合計"
printf '  %s\n' "$(human "$TOTAL_KB")"
if [ "$APPLY" -eq 1 ]; then
    printf '  削除しました。空き容量: %s\n' \
        "$(df -h /System/Volumes/Data 2>/dev/null | awk 'END {print $4}')"
else
    printf '  dry-run です。実行するには --apply を付けてください。\n'
fi
