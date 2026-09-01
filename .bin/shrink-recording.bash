#!/usr/bin/env bash
#
# shrink-recording.bash — 画面収録の .mov を配布用の mp4 に変換して軽くする。
#
# macOS の画面収録や ReplayKit の録画は 4K・高ビットレートで書き出されるため
# そのままでは共有に重い。H.264 の CRF エンコードで再圧縮し、moov atom を先頭
# に置いた（ブラウザや Slack が全部落とし切る前に再生を始められる）mp4 を、
# 入力と同じディレクトリに出力する。入力ファイルは書き換えない。
#
# 画面収録は静止領域が多くて元から圧縮しやすく、-preset を上げても縮まないので
# 既定は fast のまま。実際に効くつまみは --crf と --scale だけ。CRF は小さいほど
# 高品質で大きくなり、+6 でおよそビットレート半分。端末や小さい UI 文字が写る
# 録画は 23 前後が安全で、28 まで上げると文字にノイズが出る。
#
# フレームレートは変換しない。画面収録は可変フレームレートで、固定に直すと
# フレームの重複・間引きでカクつくため。
#
# 音声トラックは自動判定する。無ければ -an、あれば AAC 128k で再エンコードする。
#
#   shrink-recording demo.mov                 4K のまま crf 23（既定）
#   shrink-recording --scale 1920 demo.mov    横 1920 に縮小してさらに軽く
#   shrink-recording --crf 20 demo.mov        品質重視
#   shrink-recording -n *.mov                 実行せずコマンドだけ表示
#   shrink-recording -f demo.mov              既存の出力を上書きする
#
set -euo pipefail

CRF=23
PRESET=fast
SCALE=""
FORCE=0
DRY_RUN=0
INPUTS=()

while [ $# -gt 0 ]; do
    case "$1" in
    --crf)
        CRF="${2:?--crf には 0-51 の整数が必要}"
        shift
        ;;
    --preset)
        PRESET="${2:?--preset には x264 の preset 名が必要}"
        shift
        ;;
    --scale)
        SCALE="${2:?--scale には出力の横幅（ピクセル）が必要}"
        shift
        ;;
    -f | --force) FORCE=1 ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -h | --help)
        awk 'NR >= 3 { if (!/^#/) exit; sub(/^# ?/, ""); print }' "$0"
        exit 0
        ;;
    -*)
        echo "不明な引数: $1" >&2
        exit 2
        ;;
    *) INPUTS+=("$1") ;;
    esac
    shift
done

if [ "${#INPUTS[@]}" -eq 0 ]; then
    echo "入力ファイルを指定してください。使い方は --help を参照。" >&2
    exit 2
fi

case "$CRF" in
'' | *[!0-9]*)
    echo "--crf は 0-51 の整数で指定してください: $CRF" >&2
    exit 2
    ;;
esac
if [ "$CRF" -gt 51 ]; then
    echo "--crf は 0-51 の範囲で指定してください: $CRF" >&2
    exit 2
fi

if [ -n "$SCALE" ]; then
    case "$SCALE" in
    '' | *[!0-9]*)
        echo "--scale は出力の横幅をピクセル数で指定してください: $SCALE" >&2
        exit 2
        ;;
    esac
fi

for cmd in ffmpeg ffprobe; do
    if ! command -v "$cmd" >/dev/null; then
        echo "$cmd が見つかりません（brew install ffmpeg）。" >&2
        exit 1
    fi
done

# --------------------------------------------------------------------------
# ヘルパ
# --------------------------------------------------------------------------

human() {
    awk -v b="$1" 'BEGIN {
        split("B KB MB GB TB", u, " "); i = 1
        while (b >= 1024 && i < 5) { b /= 1024; i++ }
        fmt = (i == 1) ? "%d %s" : "%.1f %s"
        printf fmt, b, u[i]
    }'
}

filesize() {
    stat -f%z "$1" 2>/dev/null || stat -c%s "$1"
}

has_audio() {
    [ -n "$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$1")" ]
}

# --------------------------------------------------------------------------
# 変換
# --------------------------------------------------------------------------

failed=0

for input in "${INPUTS[@]}"; do
    if [ ! -f "$input" ]; then
        echo "見つかりません: $input" >&2
        failed=$((failed + 1))
        continue
    fi

    dir=$(dirname "$input")
    stem=$(basename "${input%.*}")
    if [ -n "$SCALE" ]; then
        output="$dir/$stem-${SCALE}w.mp4"
    else
        output="$dir/$stem.mp4"
    fi
    # 入力が既に .mp4 のときに自分自身を出力先にしないための保険。
    if [ "$output" = "$input" ]; then
        output="$dir/$stem-shrunk.mp4"
    fi

    if [ -e "$output" ] && [ "$FORCE" -eq 0 ]; then
        echo "既にあります（上書きするには -f）: $output" >&2
        failed=$((failed + 1))
        continue
    fi

    args=(-hide_banner -nostdin -y -i "$input")
    if [ -n "$SCALE" ]; then
        args+=(-vf "scale=$SCALE:-2:flags=lanczos")
    fi
    args+=(-c:v libx264 -crf "$CRF" -preset "$PRESET")
    args+=(-pix_fmt yuv420p -movflags +faststart)
    if has_audio "$input"; then
        args+=(-c:a aac -b:a 128k)
    else
        args+=(-an)
    fi
    args+=("$output")

    if [ "$DRY_RUN" -eq 1 ]; then
        printf 'ffmpeg'
        printf ' %q' "${args[@]}"
        printf '\n'
        continue
    fi

    before=$(filesize "$input")
    if ! ffmpeg "${args[@]}"; then
        echo "エンコードに失敗しました: $input" >&2
        # -y で開いた時点で中身は失われているので、壊れた出力は残さない。
        rm -f "$output"
        failed=$((failed + 1))
        continue
    fi
    after=$(filesize "$output")
    if [ "$before" -gt 0 ]; then
        pct=$((after * 100 / before))
    else
        pct=100
    fi
    printf '%s -> %s  (%s -> %s, %d%%)\n' \
        "$input" "$output" "$(human "$before")" "$(human "$after")" "$pct"
done

if [ "$failed" -ne 0 ]; then
    exit 1
fi
