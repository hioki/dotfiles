#!/usr/bin/env bash


input=$(/opt/homebrew/bin/SwitchAudioSource -c -t input)
output=$(/opt/homebrew/bin/SwitchAudioSource -c -t output)

PC="💻️"
AIRPODS="ᖰ ᖳ"
TS4="TS4"

if [[ $input == "外部マイク" ]]; then
  input="🎤"
elif [[ $input == "MacBook Proのマイク" ]]; then
  input=$PC
elif [[ $input =~ "AirPods" ]]; then
  input=$AIRPODS
elif [[ $input == "CalDigit TS4 Audio - Front" ]]; then
  input=$TS4
fi

if [[ $output == "外部ヘッドフォン" ]]; then
  output="🎧️"
elif [[ $output == "MacBook Proのスピーカー" ]]; then
  output=$PC
elif [[ $output =~ "AirPods" ]]; then
  output=$AIRPODS
elif [[ $output == "CalDigit TS4 Audio - Front" ]]; then
  output=$TS4
fi

echo "$input/$output"
