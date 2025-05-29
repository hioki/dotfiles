#!/usr/bin/env bash

source ".switchbot.env"
json=$(curl -s \
  -H "Authorization: $SWITCHBOT_PRIVATE_ACCOUNT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.switch-bot.com/v1.1/devices/$SWITCHBOT_CO2_DEVICE_ID/status")
co2=$(echo "$json" | jq -r '.body.CO2')

if   [[ $co2 -ge 1500 ]]; then  color="#FF9999"
elif [[ $co2 -ge 1000 ]]; then  color="#FFDD99"
else                            color="#BBFFBB"
fi

echo "💨${co2} | color=${color}"

# --- 以下はクリックで開くドロップダウン（任意） -------
temp=$(echo "$json" | jq -r '.body.temperature')
humi=$(echo "$json" | jq -r '.body.humidity')
echo "---"
echo "温度: ${temp} ℃"
echo "湿度: ${humi} %"
echo "更新: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Refresh | refresh=true"
