#!/bin/bash
# <xbar.title>Mic Slider Level</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>hioki</xbar.author>
# <xbar.desc>Displays the macOS System Input Volume slider value.</xbar.desc>
# <xbar.refresh>5s</xbar.refresh>

# AppleScript で「入力音量スライダー」の現在値を取得（0～100 の整数）
VOL=$(osascript -e 'input volume of (get volume settings)')

if [ "$VOL" = "missing value" ]; then
  VOL="-"
else
  if ! [[ "$VOL" =~ ^[0-9]+$ ]]; then
    VOL="-"
  fi
fi

# メニューバーにパーセント表示
echo "📢${VOL}%"
echo "---"
echo "スライダー値: ${VOL}%"
echo "更新: $(date '+%H:%M:%S')"
