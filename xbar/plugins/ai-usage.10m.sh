#!/usr/bin/env bash
# <xbar.title>AI Usage (Claude Code / Codex)</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>hioki</xbar.author>
# <xbar.desc>Claude Code と Codex のレート利用率を表示し、上限に近づく前に気づけるようにする</xbar.desc>
# <xbar.dependencies>jq,curl,codex-cli</xbar.dependencies>

# xbar は最小 PATH で起動されるため homebrew を通す
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# --- 閾値 (利用率 %) -------------------------------------------------
WARN=70    # 🟠 注意
CRIT=90    # 🔴 危険
# --------------------------------------------------------------------

sig() {   # 利用率(整数) -> 信号絵文字
  local p=${1:-0}
  if   [ "$p" -ge "$CRIT" ]; then echo "🔴"
  elif [ "$p" -ge "$WARN" ]; then echo "🟠"
  else echo "🟢"; fi
}
clr() {   # 利用率(整数) -> xbar の color 指定 (normal は空)
  local p=${1:-0}
  if   [ "$p" -ge "$CRIT" ]; then echo "red"
  elif [ "$p" -ge "$WARN" ]; then echo "#6c3300"; fi
}
fmt_dur() {   # 残り秒 -> "1d2h" / "2h30m" / "45m"
  local s=${1:-0}
  [ "$s" -lt 0 ] && s=0
  local d=$((s/86400)) h=$(((s%86400)/3600)) m=$(((s%3600)/60))
  if   [ "$d" -gt 0 ]; then echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then echo "${h}h${m}m"
  else echo "${m}m"; fi
}

now=$(date +%s)

# ==== Claude Code ===================================================
tok=$(jq -r '.claudeAiOauth.accessToken // empty' "$HOME/.claude/.credentials.json" 2>/dev/null)
[ -z "$tok" ] && tok=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
                        | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)

claude_ok=0; cmax=0; cj=""
if [ -n "$tok" ]; then
  cj=$(curl -s --max-time 10 "https://api.anthropic.com/api/oauth/usage" \
        -H "Authorization: Bearer $tok" \
        -H "anthropic-beta: oauth-2025-04-20")
  if echo "$cj" | jq -e '.five_hour' >/dev/null 2>&1; then
    claude_ok=1
    cmax=$(echo "$cj" | jq -r '
      ([.limits[]?.percent] + [.five_hour.utilization, .seven_day.utilization]
       | map(select(. != null)) | max // 0) | round')
  fi
fi

# ==== Codex =========================================================
xj=$( { printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"xbar-ai-usage","version":"1.0"}}}' \
    '{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{}}'
    sleep 5
  } | codex app-server 2>/dev/null | jq -c 'select(.id==2).result.rateLimits' 2>/dev/null | head -1 )

codex_ok=0; xmax=0; xp=0; xs=0
if [ -n "$xj" ] && [ "$xj" != "null" ]; then
  codex_ok=1
  xp=$(echo "$xj" | jq -r '(.primary.usedPercent   // 0) | round')
  xs=$(echo "$xj" | jq -r '(.secondary.usedPercent // 0) | round')
  xmax=$(( xp > xs ? xp : xs ))
fi

# ==== メニューバー行 =================================================
if [ "$claude_ok" = 1 ]; then c_seg="$(sig "$cmax")C${cmax}%"; else c_seg="⚠️C"; fi
if [ "$codex_ok"  = 1 ]; then x_seg="$(sig "$xmax")X${xmax}%"; else x_seg="⚠️X"; fi

overall=$(( cmax > xmax ? cmax : xmax ))
line_color=""
lc=$(clr "$overall"); [ -n "$lc" ] && line_color="| color=$lc"
echo "$c_seg $x_seg $line_color"

echo "---"

# ==== ドロップダウン: Claude ========================================
echo "Claude Code | href=https://claude.ai/settings/usage"
if [ "$claude_ok" = 1 ]; then
  # limits[] を1行ずつ。区切りはパイプ(値に出現しない)。空欄は "-" で埋める。
  echo "$cj" | jq -r '
    def kindname:
      { "session":"5時間", "weekly_all":"週(全体)", "weekly_scoped":"週(モデル別)" }[.] // .;
    .limits[]?
    | [ (.kind|kindname),
        (.percent|tostring),
        (.resets_at // "-"),
        (.scope.model.display_name // "-"),
        (.is_active|tostring) ] | join("|")' \
  | while IFS='|' read -r kind pct reset model active; do
      # リセットまでの残り時間 (resets_at: ISO8601 UTC)。jq -R で生文字列として読む。
      rem=""
      if [ "$reset" != "-" ] && [ -n "$reset" ]; then
        re=$(echo "$reset" | jq -rR 'sub("\\.[0-9]+";"") | sub("[+-][0-9:]+$";"")
                                     | strptime("%Y-%m-%dT%H:%M:%S") | mktime' 2>/dev/null)
        [ -n "$re" ] && rem="  ↻$(fmt_dur $((re-now)))"
      fi
      name="$kind"; [ "$model" != "-" ] && name="${kind}:${model}"
      star=""; [ "$active" = "true" ] && star="●"
      col=$(clr "$pct"); cp=""; [ -n "$col" ] && cp="| color=$col"
      printf -- "%s %-16s %3s%%%s %s\n" "$(sig "$pct")" "$name$star" "$pct" "$rem" "$cp"
    done
else
  echo "⚠️ 取得失敗 (未ログイン / トークン失効?) | color=red"
fi

echo "---"

# ==== ドロップダウン: Codex =========================================
echo "Codex"
if [ "$codex_ok" = 1 ]; then
  xpr=$(echo "$xj" | jq -r '.primary.resetsAt   // empty')
  xsr=$(echo "$xj" | jq -r '.secondary.resetsAt // empty')
  xpw=$(echo "$xj" | jq -r '(.primary.windowDurationMins   // 0)')
  xsw=$(echo "$xj" | jq -r '(.secondary.windowDurationMins // 0)')
  pr=""; [ -n "$xpr" ] && pr="  ↻$(fmt_dur $((xpr-now)))"
  sr=""; [ -n "$xsr" ] && sr="  ↻$(fmt_dur $((xsr-now)))"
  cp=$(clr "$xp"); cpp=""; [ -n "$cp" ] && cpp="| color=$cp"
  cs=$(clr "$xs"); css=""; [ -n "$cs" ] && css="| color=$cs"
  printf -- "%s %-16s %3s%%%s %s\n" "$(sig "$xp")" "5時間($((xpw/60))h)"  "$xp" "$pr" "$cpp"
  printf -- "%s %-16s %3s%%%s %s\n" "$(sig "$xs")" "週($((xsw/1440))d)"   "$xs" "$sr" "$css"
else
  echo "⚠️ 取得失敗 (codex app-server 応答なし) | color=red"
fi

echo "---"
echo "🔄 更新 | refresh=true"
echo "$(date '+%H:%M:%S') 更新 | color=gray"
