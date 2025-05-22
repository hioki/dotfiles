#!/usr/bin/env bash

echo "$(/opt/homebrew/bin/SwitchAudioSource -c -t input)/$(/opt/homebrew/bin/SwitchAudioSource -c -t output)"
