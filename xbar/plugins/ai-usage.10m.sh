#!/usr/bin/env bash
# <xbar.title>AI Usage (Claude Code / Codex / Copilot)</xbar.title>
# <xbar.version>v1.0</xbar.version>
# <xbar.author>hioki</xbar.author>
# <xbar.desc>Claude Code / Codex / GitHub Copilot のレート利用率を表示し、上限に近づく前に気づけるようにする</xbar.desc>
# <xbar.dependencies>jq,curl,codex-cli</xbar.dependencies>

# xbar は最小 PATH で起動されるため homebrew を通す
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# --- 閾値 (利用率 %) -------------------------------------------------
WARN=70    # 🟡 注意
CRIT=90    # 🔴 危険
# --------------------------------------------------------------------

sig() {   # 利用率(整数) -> 信号絵文字
  local p=${1:-0}
  if   [ "$p" -ge "$CRIT" ]; then echo "🔴"
  elif [ "$p" -ge "$WARN" ]; then echo "🟡"
  else echo "🟢"; fi
}
clr() {   # 利用率(整数) -> xbar の color 指定 (normal は空)
  local p=${1:-0}
  if   [ "$p" -ge "$CRIT" ]; then echo "red"
  elif [ "$p" -ge "$WARN" ]; then echo "orange"; fi
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

# ==== GitHub Copilot ================================================
gtok=$(jq -r 'to_entries[0].value.oauth_token // empty' "$HOME/.config/github-copilot/apps.json" 2>/dev/null)

cop_ok=0; gmax=0; gplan=""; gorg=""; greset=""; gchat="∞"; gcomp="∞"; gprem=0; gprem_cr=0
GPREM_LIMIT=1900   # premium requests は月1900を超えると都度課金
if [ -n "$gtok" ]; then
  gj=$(curl -s --max-time 8 "https://api.github.com/copilot_internal/user" \
        -H "Authorization: Bearer $gtok" \
        -H "Editor-Version: vscode/1.96.0" \
        -H "User-Agent: GithubCopilot/1.155.0" \
        -H "Accept: application/json")
  if echo "$gj" | jq -e '.quota_snapshots' >/dev/null 2>&1; then
    cop_ok=1
    # chat/completions は unlimited なら "∞"、それ以外は used% (100 - percent_remaining)。
    # premium は API が unlimited を返しても実際は月1900を超えると都度課金なので、
    # credits_used / 1900 で使用率を計算する。区切りはパイプ。
    IFS='|' read -r gplan gorg greset_iso gchat gcomp gprem gprem_cr <<<"$(echo "$gj" | jq -r --argjson lim "$GPREM_LIMIT" '
      def u($q): (.quota_snapshots[$q] // {})
        | if .unlimited == true then "∞"
          else ((100 - (.percent_remaining // 100)) | round | tostring) end;
      ((.quota_snapshots.premium_interactions.credits_used // 0)) as $cr
      | [ .copilot_plan // "-",
          (.organization_login_list[0] // "-"),
          (.quota_reset_date_utc // "-"),
          u("chat"), u("completions"),
          (($cr * 100 / $lim) | round | tostring),
          ($cr | tostring)
        ] | join("|")')"
    gmax=$gprem
    for v in "$gchat" "$gcomp"; do
      [ "$v" != "∞" ] && [ "$v" -gt "$gmax" ] 2>/dev/null && gmax=$v
    done
    # リセットまでの残り時間 (quota_reset_date_utc: ISO8601)
    if [ "$greset_iso" != "-" ] && [ -n "$greset_iso" ]; then
      gre=$(echo "$greset_iso" | jq -rR 'sub("\\.[0-9]+";"") | sub("Z$";"") | sub("[+-][0-9:]+$";"")
                                       | strptime("%Y-%m-%dT%H:%M:%S") | mktime' 2>/dev/null)
      [ -n "$gre" ] && greset="  ↻$(fmt_dur $((gre-now)))"
    fi
  fi
fi

# ==== メニューバー行 =================================================
if [ "$claude_ok" = 1 ]; then c_seg="$(sig "$cmax")C${cmax}%"; else c_seg="⚠️C"; fi
if [ "$codex_ok"  = 1 ]; then x_seg="$(sig "$xmax")X${xmax}%"; else x_seg="⚠️X"; fi
if [ "$cop_ok"    = 1 ]; then
  g_seg="$(sig "$gmax")G${gmax}%"
else g_seg="⚠️G"; fi

overall=$(( cmax > xmax ? cmax : xmax ))
overall=$(( overall > gmax ? overall : gmax ))
line_color=""
lc=$(clr "$overall"); [ -n "$lc" ] && line_color="| color=$lc"
echo "$c_seg $x_seg $g_seg $line_color"

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

# ==== ドロップダウン: GitHub Copilot =================================
echo "GitHub Copilot | href=https://github.com/settings/copilot"
if [ "$cop_ok" = 1 ]; then
  echo "$gplan${gorg:+ ($gorg)} | color=gray"
  grow() {   # $1:名前 $2:"used%" または "∞" $3:追記文字列
    local name=$1 v=$2 extra=$3 num=0 disp col cp=""
    [ "$v" != "∞" ] && num=$v
    if [ "$v" = "∞" ]; then disp=$(printf "%4s" "∞"); else disp=$(printf "%3s%%" "$v"); fi
    col=$(clr "$num"); [ -n "$col" ] && cp="| color=$col"
    printf -- "%s %-16s %s%s %s\n" "$(sig "$num")" "$name" "$disp" "$extra" "$cp"
  }
  grow "Chat"            "$gchat" ""
  grow "Completions"     "$gcomp" ""
  grow "Premium requests" "$gprem" "  (${gprem_cr}/${GPREM_LIMIT} req)$greset"
else
  echo "⚠️ 取得失敗 (apps.json なし / トークン失効?) | color=red"
fi

echo "---"
echo "🔄 更新 | refresh=true"
echo "$(date '+%H:%M:%S') 更新 | color=gray"
