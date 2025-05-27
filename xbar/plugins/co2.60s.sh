#!/bin/bash

source ".switchbot.env"
CO2=$(curl -s \
  -H "Authorization: $SWITCHBOT_PRIVATE_ACCOUNT_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.switch-bot.com/v1.1/devices/$SWITCHBOT_CO2_DEVICE_ID/status" \
| jq '.body.CO2')
echo "${CO2} ppm"
