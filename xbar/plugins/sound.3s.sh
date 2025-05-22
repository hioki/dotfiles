#!/usr/bin/env bash

echo "$(/opt/homebrew/bin/SwitchAudioSource -c -t input | cut -c -3)/$(/opt/homebrew/bin/SwitchAudioSource -c -t output | cut -c -3)"
