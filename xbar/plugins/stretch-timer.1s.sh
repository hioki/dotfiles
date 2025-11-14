#!/usr/bin/env bash
# <xbar.title>Stretch Interval Timer</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>hioki</xbar.author>
# <xbar.desc>ストレッチ用のインターバルタイマー（音声通知付き）</xbar.desc>
# <xbar.refresh>1s</xbar.refresh>
# <xbar.var>number(VAR_INTERVAL=30): 1セットの秒数</xbar.var>
# <xbar.var>number(VAR_ROUNDS=10): 総セット数</xbar.var>

STATE_FILE="$HOME/.xbar_stretch_timer"

is_positive_int() {
  [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ]
}

play_sound() {
  local sound="$1"
  local sound_file="/System/Library/Sounds/${sound}.aiff"
  if command -v afplay >/dev/null 2>&1 && [ -f "$sound_file" ]; then
    afplay "$sound_file" >/dev/null 2>&1 &
  else
    osascript -e 'beep' >/dev/null 2>&1
  fi
}

short_beep() {
  play_sound "Glass"
}

long_beep() {
  play_sound "Ping"
}

save_state() {
  printf "%s|%s|%s|%s|%s|%s\n" \
    "$STATUS" "$CURRENT_ROUND" "$ROUND_START" "$LAST_REMAINING" "$ACTIVE_INTERVAL" "$ACTIVE_ROUNDS" >"$STATE_FILE"
}

format_time() {
  local seconds=$1
  if [ "$seconds" -lt 0 ]; then
    seconds=0
  fi
  local minutes=$((seconds / 60))
  local remain=$((seconds % 60))
  printf "%02d:%02d" "$minutes" "$remain"
}

DEFAULT_INTERVAL=${VAR_INTERVAL:-30}
DEFAULT_ROUNDS=${VAR_ROUNDS:-10}

if ! is_positive_int "$DEFAULT_INTERVAL"; then
  DEFAULT_INTERVAL=30
fi

if ! is_positive_int "$DEFAULT_ROUNDS"; then
  DEFAULT_ROUNDS=10
fi

STATUS="stopped"
CURRENT_ROUND=0
ROUND_START=0
LAST_REMAINING=$DEFAULT_INTERVAL
ACTIVE_INTERVAL=$DEFAULT_INTERVAL
ACTIVE_ROUNDS=$DEFAULT_ROUNDS

if [ -f "$STATE_FILE" ]; then
  if IFS='|' read -r STATUS CURRENT_ROUND ROUND_START LAST_REMAINING ACTIVE_INTERVAL ACTIVE_ROUNDS <"$STATE_FILE"; then
    :
  fi
fi

case "$STATUS" in
running|completed)
  ;;
*)
  STATUS="stopped"
  ;;
esac

[[ "$CURRENT_ROUND" =~ ^[0-9]+$ ]] || CURRENT_ROUND=0
[[ "$ROUND_START" =~ ^[0-9]+$ ]] || ROUND_START=0
[[ "$LAST_REMAINING" =~ ^[0-9]+$ ]] || LAST_REMAINING=$DEFAULT_INTERVAL
[[ "$ACTIVE_INTERVAL" =~ ^[0-9]+$ ]] || ACTIVE_INTERVAL=$DEFAULT_INTERVAL
[[ "$ACTIVE_ROUNDS" =~ ^[0-9]+$ ]] || ACTIVE_ROUNDS=$DEFAULT_ROUNDS

if [ "$ACTIVE_INTERVAL" -le 0 ]; then
  ACTIVE_INTERVAL=$DEFAULT_INTERVAL
fi

if [ "$ACTIVE_ROUNDS" -le 0 ]; then
  ACTIVE_ROUNDS=$DEFAULT_ROUNDS
fi

if [ "$1" = "start" ]; then
  STATUS="running"
  ACTIVE_INTERVAL=$DEFAULT_INTERVAL
  ACTIVE_ROUNDS=$DEFAULT_ROUNDS
  CURRENT_ROUND=1
  ROUND_START=$(date +%s)
  LAST_REMAINING=$ACTIVE_INTERVAL
  save_state
  exit 0
elif [ "$1" = "stop" ]; then
  rm -f "$STATE_FILE"
  exit 0
elif [ "$1" = "reset" ]; then
  rm -f "$STATE_FILE"
  exit 0
fi

if [ "$STATUS" = "running" ]; then
  NOW=$(date +%s)
  if [ "$ROUND_START" -le 0 ]; then
    ROUND_START=$NOW
  fi

  ELAPSED=$((NOW - ROUND_START))
  REMAINING=$((ACTIVE_INTERVAL - ELAPSED))

  while [ "$REMAINING" -le 0 ]; do
    long_beep
    if [ "$CURRENT_ROUND" -ge "$ACTIVE_ROUNDS" ]; then
      STATUS="completed"
      LAST_REMAINING=0
      save_state
      break
    else
      CURRENT_ROUND=$((CURRENT_ROUND + 1))
      ROUND_START=$((ROUND_START + ACTIVE_INTERVAL))
      if [ "$ROUND_START" -gt "$NOW" ]; then
        ROUND_START=$NOW
      fi
      ELAPSED=$((NOW - ROUND_START))
      REMAINING=$((ACTIVE_INTERVAL - ELAPSED))
      LAST_REMAINING=$ACTIVE_INTERVAL
      save_state
    fi
  done

  if [ "$STATUS" = "running" ]; then
    if [ "$REMAINING" -lt 0 ]; then
      REMAINING=0
    fi
    if [ "$LAST_REMAINING" -ne "$REMAINING" ] && [ "$REMAINING" -le 3 ] && [ "$REMAINING" -ge 1 ]; then
      short_beep
    fi
    LAST_REMAINING=$REMAINING
    save_state
  fi
fi

if [ "$STATUS" = "completed" ]; then
  MAIN_LINE="🧘 完了 ${ACTIVE_ROUNDS}/${ACTIVE_ROUNDS}"
elif [ "$STATUS" = "running" ]; then
  MAIN_LINE=$(printf "🧘 %s R%d/%d" "$(format_time "$LAST_REMAINING")" "$CURRENT_ROUND" "$ACTIVE_ROUNDS")
else
  MAIN_LINE=$(printf "🧘 Ready %ss×%d" "$DEFAULT_INTERVAL" "$DEFAULT_ROUNDS")
fi

echo "$MAIN_LINE"
echo "---"

if [ "$STATUS" = "running" ]; then
  echo "セット ${CURRENT_ROUND}/${ACTIVE_ROUNDS}"
  echo "残り時間: $(format_time "$LAST_REMAINING")"
  echo "1セット: ${ACTIVE_INTERVAL}秒"
elif [ "$STATUS" = "completed" ]; then
  echo "すべてのセットが完了しました"
  echo "実行設定: ${ACTIVE_INTERVAL}秒 × ${ACTIVE_ROUNDS}回"
else
  echo "プリセット: ${DEFAULT_INTERVAL}秒 × ${DEFAULT_ROUNDS}回"
fi

echo "---"

if [ "$STATUS" = "running" ]; then
  echo "停止 | bash='$0' param1=stop terminal=false refresh=true"
  echo "リセット | bash='$0' param1=reset terminal=false refresh=true"
else
  echo "開始 (${DEFAULT_INTERVAL}秒 × ${DEFAULT_ROUNDS}回) | bash='$0' param1=start terminal=false refresh=true"
  if [ -f "$STATE_FILE" ]; then
    echo "リセット | bash='$0' param1=reset terminal=false refresh=true"
  fi
fi
