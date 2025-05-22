#!/usr/bin/env bash


input=$(/opt/homebrew/bin/SwitchAudioSource -c -t input)
output=$(/opt/homebrew/bin/SwitchAudioSource -c -t output)

PC="💻️"
AIRPODS="ᖰ ᖳ"

if [[ $input == "外部マイク" ]]; then
  input="🎤"
elif [[ $input == "MacBook Proのマイク" ]]; then
  input=$PC
elif [[ $input =~ "AirPods" ]]; then
  input=$AIRPODS
fi

if [[ $output == "外部ヘッドフォン" ]]; then
  output="🎧️"
elif [[ $output == "MacBook Proのスピーカー" ]]; then
  output=$PC
elif [[ $output =~ "AirPods" ]]; then
  output=$AIRPODS
fi

echo "$input/$output"
