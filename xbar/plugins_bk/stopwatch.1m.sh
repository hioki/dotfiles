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
  elif [ $ELAPSED_MINUTES -ge 50 ]; then
    COLOR="#FFAA00"
  else
    COLOR=""
  fi

  if [ -n "$COLOR" ]; then
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
  echo "---"
  echo "時間調整"
  echo "-- +1分 | bash='$0' param1=adjust param2=+60 terminal=false refresh=true"
  echo "-- +5分 | bash='$0' param1=adjust param2=+300 terminal=false refresh=true"
  echo "-- +10分 | bash='$0' param1=adjust param2=+600 terminal=false refresh=true"
  echo "-- +15分 | bash='$0' param1=adjust param2=+600 terminal=false refresh=true"
  echo "-- +20分 | bash='$0' param1=adjust param2=+1200 terminal=false refresh=true"
  echo "-- +25分 | bash='$0' param1=adjust param2=+1500 terminal=false refresh=true"
  echo "-- +30分 | bash='$0' param1=adjust param2=+1800 terminal=false refresh=true"
  echo "-- -1分 | bash='$0' param1=adjust param2=-60 terminal=false refresh=true"
  echo "-- -5分 | bash='$0' param1=adjust param2=-300 terminal=false refresh=true"
  echo "-- -10分 | bash='$0' param1=adjust param2=-600 terminal=false refresh=true"
  echo "-- -15分 | bash='$0' param1=adjust param2=-900 terminal=false refresh=true"
  echo "-- -20分 | bash='$0' param1=adjust param2=-1200 terminal=false refresh=true"
  echo "-- -25分 | bash='$0' param1=adjust param2=-1500 terminal=false refresh=true"
  echo "-- -30分 | bash='$0' param1=adjust param2=-1800 terminal=false refresh=true"
  echo "---"
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
elif [ "$1" = "adjust" ]; then
  if [ -f "$TIMER_FILE" ]; then
    START_TIME=$(cat "$TIMER_FILE")
    # 調整値は秒単位（+60 or -60）
    ADJUSTMENT=$2
    NEW_START_TIME=$((START_TIME - ADJUSTMENT))
    echo "$NEW_START_TIME" > "$TIMER_FILE"
  fi
fi
