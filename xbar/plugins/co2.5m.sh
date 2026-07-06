#!/usr/bin/env bash

source ".switchbot.env"
json=$(curl -s \
  -H "Authorization: $SWITCHBOT_PRIVATE_ACCOUNT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.switch-bot.com/v1.1/devices/$SWITCHBOT_CO2_DEVICE_ID/status")
co2=$(echo "$json" | jq -r '.body.CO2')
#temp=$(echo "$json" | jq -r '.body.temperature')
#humi=$(echo "$json" | jq -r '.body.humidity')

# メニューバーに全て表示（1行にまとめる）
echo "💨${co2}"
#echo "💨${co2} 🌡️${temp}℃ 💧${humi}%"

## --- 以下はクリックで開くドロップダウン（任意） -------
#echo "---"
#echo "温度: ${temp} ℃"
#echo "湿度: ${humi} %"
#echo "更新: $(date '+%Y-%m-%d %H:%M:%S')"
#echo "Refresh | refresh=true"
