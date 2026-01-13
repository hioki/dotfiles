#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/karaconf/shingeta_mode"

if [ -f "$STATE_FILE" ]; then
  state="$(cat "$STATE_FILE")"
else
  state="off"
fi

if [ "$state" = "on" ]; then
  echo "🩴"
else
  echo "👣"
fi

echo "---"
echo "State: $state"
