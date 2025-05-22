#!/usr/bin/env bash


input=$(/opt/homebrew/bin/SwitchAudioSource -c -t input)
output=$(/opt/homebrew/bin/SwitchAudioSource -c -t output)

if [[ $input == "外部マイク" ]]; then
  input="🎤"
elif [[ $input == "MacBook Proのマイク" ]]; then
  input="💻️"
fi

if [[ $output == "外部ヘッドフォン" ]]; then
  output="🎧️"
elif [[ $output == "MacBook Proのスピーカー" ]]; then
  output="💻️"
fi

echo "in: $input, out: $output"
