#!/usr/bin/env bash
# <xbar.title>Stopwatch</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>hioki</xbar.author>
# <xbar.desc>Displays elapsed time in minutes with color coding</xbar.desc>
# <xbar.refresh>1m</xbar.refresh>

TIMER_FILE="$HOME/.xbar_stopwatch"

if [ -f "$TIMER_FILE" ]; then
  START_TIME=$(cat "$TIMER_FILE")
  CURRENT_TIME=$(date +%s)
  ELAPSED_SECONDS=$((CURRENT_TIME - START_TIME))
  ELAPSED_MINUTES=$((ELAPSED_SECONDS / 60))

  if [ $ELAPSED_MINUTES -ge 60 ]; then
    COLOR="#FF0000"
    STYLE="bold"
  elif [ $ELAPSED_MINUTES -ge 50 ]; then
    COLOR="#FFAA00"
    STYLE=""
  else
    COLOR=""
    STYLE=""
  fi

  if [ -n "$COLOR" ] && [ -n "$STYLE" ]; then
    echo "⏱ ${ELAPSED_MINUTES}m | color=$COLOR $STYLE=true"
  elif [ -n "$COLOR" ]; then
    echo "⏱ ${ELAPSED_MINUTES}m | color=$COLOR"
  else
    echo "⏱ ${ELAPSED_MINUTES}m"
  fi

  echo "---"
  echo "経過時間: ${ELAPSED_MINUTES}分"
  HOURS=$((ELAPSED_MINUTES / 60))
  MINUTES=$((ELAPSED_MINUTES % 60))
  if [ $HOURS -gt 0 ]; then
    echo "詳細: ${HOURS}時間${MINUTES}分"
  fi
  echo "停止 | bash='$0' param1=stop terminal=false refresh=true"
else
  echo "⏱ -m"
  echo "---"
  echo "停止中"
  echo "開始 | bash='$0' param1=start terminal=false refresh=true"
fi

if [ "$1" = "start" ]; then
  date +%s > "$TIMER_FILE"
elif [ "$1" = "stop" ]; then
  rm -f "$TIMER_FILE"
fi
