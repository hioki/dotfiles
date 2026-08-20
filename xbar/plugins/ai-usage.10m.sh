#!/usr/bin/env bash
# <xbar.title>AI Usage (Claude Code / Codex / Copilot)</xbar.title>
# <xbar.version>v1.1</xbar.version>
# <xbar.author>hioki</xbar.author>
# <xbar.desc>Claude Code / Codex / GitHub Copilot のレート利用率を表示し、上限に近づく前に気づけるようにする</xbar.desc>
# <xbar.dependencies>jq,curl,codex-cli</xbar.dependencies>

# xbar は最小 PATH で起動されるため homebrew を通す
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# --- 閾値 (利用率 %) -------------------------------------------------
WARN=70    # 🟠 注意
CRIT=90    # 🔴 危険
# --------------------------------------------------------------------

# --- Claude Code の OAuth 情報 ---------------------------------------
# アクセストークンは約8時間で失効し、Claude Code 本体が動いていないと更新
# されない。放置すると usage API が 401 を返し続けるため、失効時はこの
# プラグイン側で refreshToken を使って再発行し、書き戻す。
KC_SERVICE="Claude Code-credentials"
CRED_FILE="$HOME/.claude/.credentials.json"
STATE_DIR="$HOME/.config/ai-usage"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
OAUTH_TOKEN_URL="https://api.anthropic.com/v1/oauth/token"
OAUTH_CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
OAUTH_BETA="oauth-2025-04-20"
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
win_label() {   # 窓の長さ(分) -> "5時間" / "7日"
  local m=${1:-0}
  if   [ "$m" -le 0 ];          then echo "?"
  elif [ $((m % 1440)) -eq 0 ]; then echo "$((m/1440))日"
  elif [ $((m % 60))   -eq 0 ]; then echo "$((m/60))時間"
  else echo "${m}分"; fi
}

now=$(date +%s)
now_ms=$((now * 1000))

# ==== Claude Code ===================================================
# 認証情報はファイル優先、無ければ keychain から読む
cred_src=""; creds=""
if [ -s "$CRED_FILE" ]; then
  creds=$(cat "$CRED_FILE" 2>/dev/null); cred_src="file"
fi
if ! jq -e '.claudeAiOauth.accessToken' <<<"$creds" >/dev/null 2>&1; then
  creds=$(security find-generic-password -s "$KC_SERVICE" -w 2>/dev/null); cred_src="keychain"
fi

save_creds() {   # $1: 更新後の認証情報 JSON。書き戻し前に旧値を退避する
  local json="$1" acct back
  mkdir -p "$STATE_DIR" 2>/dev/null && chmod 700 "$STATE_DIR" 2>/dev/null
  printf '%s' "$creds" > "$STATE_DIR/credentials.prev.json" || return 1
  chmod 600 "$STATE_DIR/credentials.prev.json" 2>/dev/null
  if [ "$cred_src" = "file" ]; then
    printf '%s' "$json" > "$CRED_FILE" || return 1
    chmod 600 "$CRED_FILE" 2>/dev/null
    back=$(cat "$CRED_FILE" 2>/dev/null)
  else
    # keychain の acct 属性は Claude Code が作ったものをそのまま使う
    acct=$(security find-generic-password -s "$KC_SERVICE" 2>/dev/null \
            | awk -F'"' '/"acct"<blob>=/ {print $4}')
    [ -z "$acct" ] && acct="$USER"
    security add-generic-password -U -s "$KC_SERVICE" -a "$acct" -w "$json" 2>/dev/null || return 1
    back=$(security find-generic-password -s "$KC_SERVICE" -w 2>/dev/null)
  fi
  # 読み直して実際に反映されたか確認する
  [ "$(jq -r '.claudeAiOauth.accessToken // empty' <<<"$back" 2>/dev/null)" \
      = "$(jq -r '.claudeAiOauth.accessToken // empty' <<<"$json" 2>/dev/null)" ]
}

refresh_creds() {   # refreshToken でアクセストークンを再発行する
  local rt resp at new
  rt=$(jq -r '.claudeAiOauth.refreshToken // empty' <<<"$creds" 2>/dev/null)
  [ -z "$rt" ] && { claude_err="リフレッシュ不可: refreshToken なし"; return 1; }
  resp=$(curl -s --max-time 15 "$OAUTH_TOKEN_URL" \
          -H 'Content-Type: application/json' \
          -H "anthropic-beta: $OAUTH_BETA" \
          -d "$(jq -nc --arg rt "$rt" --arg cid "$OAUTH_CLIENT_ID" \
                '{grant_type:"refresh_token",refresh_token:$rt,client_id:$cid}')")
  at=$(jq -r '.access_token // empty' <<<"$resp" 2>/dev/null)
  if [ -z "$at" ]; then
    claude_err="リフレッシュ失敗: $(jq -r '.error // "応答不正"' <<<"$resp" 2>/dev/null) → claude auth login"
    return 1
  fi
  new=$(jq -c --argjson r "$resp" --argjson now "$now_ms" '
    .claudeAiOauth.accessToken    = $r.access_token
    | .claudeAiOauth.refreshToken = ($r.refresh_token // .claudeAiOauth.refreshToken)
    | .claudeAiOauth.expiresAt    = ($now + ((($r.expires_in // 28800) | floor) * 1000))
    | .claudeAiOauth.scopes       = (if ($r.scope // "") == "" then .claudeAiOauth.scopes
                                     else ($r.scope | split(" ")) end)' <<<"$creds" 2>/dev/null)
  [ -z "$new" ] && { claude_err="リフレッシュ失敗: 認証情報の更新に失敗"; return 1; }
  # 保存に失敗しても今回の取得には使えるので、警告だけ残して続行する
  save_creds "$new" || claude_err="保存失敗 (旧値: $STATE_DIR/credentials.prev.json)"
  creds="$new"; tok="$at"
}

call_usage() {   # usage API を叩いて cj / chttp を埋める
  local out
  out=$(curl -s -w '\n%{http_code}' --max-time 10 "$USAGE_URL" \
        -H "Authorization: Bearer $tok" -H "anthropic-beta: $OAUTH_BETA")
  chttp=$(printf '%s' "$out" | tail -1)
  cj=$(printf '%s' "$out" | sed '$d')
}

claude_ok=0; cmax=0; cj=""; chttp=""; claude_err=""; tok=""; exp_ms=0
if jq -e '.claudeAiOauth.accessToken' <<<"$creds" >/dev/null 2>&1; then
  tok=$(jq -r '.claudeAiOauth.accessToken' <<<"$creds")
  exp_ms=$(jq -r '(.claudeAiOauth.expiresAt // 0) | floor' <<<"$creds")
else
  claude_err="未ログイン → claude auth login"
fi

if [ -n "$tok" ]; then
  # 失効 (1分前を含む) なら先に再発行しておく。
  # AI_USAGE_FORCE_REFRESH=1 を付けるとリフレッシュ経路を手動で試せる。
  if [ -n "$AI_USAGE_FORCE_REFRESH" ] ||
     { [ "$exp_ms" -gt 0 ] && [ "$now_ms" -ge $((exp_ms - 60000)) ]; }; then
    refresh_creds
  fi
  call_usage
  # 期限内のはずでも弾かれたら一度だけ再発行して再試行する
  if [ "$chttp" = "401" ] || [ "$chttp" = "403" ]; then
    refresh_creds && call_usage
  fi
  if [ "$chttp" = "200" ] && jq -e '.limits' <<<"$cj" >/dev/null 2>&1; then
    claude_ok=1
    cmax=$(jq -r '
      ([.limits[]?.percent] + [.five_hour.utilization, .seven_day.utilization]
       | map(select(. != null)) | max // 0) | round' <<<"$cj")
  elif [ -z "$claude_err" ]; then
    claude_err="HTTP ${chttp:-応答なし}"
  fi
fi

# ==== Codex =========================================================
xj=$( { printf '%s\n' \
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"xbar-ai-usage","version":"1.0"}}}' \
    '{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{}}'
    sleep 5
  } | codex app-server 2>/dev/null | jq -c 'select(.id==2).result.rateLimits' 2>/dev/null | head -1 )

codex_ok=0; xmax=0; xrows=""
if [ -n "$xj" ] && [ "$xj" != "null" ]; then
  # primary/secondary のどちらが5時間窓/週窓かはプラン次第で、片方 null もある。
  # 窓の長さ (windowDurationMins) から判断し、短い窓から並べる。
  xrows=$(jq -r '
    [.primary, .secondary] | map(select(type == "object"))
    | sort_by(.windowDurationMins // 0)
    | .[] | [ ((.windowDurationMins // 0) | floor),
              ((.usedPercent // 0) | round),
              ((.resetsAt // 0) | floor) ] | map(tostring) | join("|")' <<<"$xj" 2>/dev/null)
  if [ -n "$xrows" ]; then
    codex_ok=1
    while IFS='|' read -r w p r; do
      [ "${p:-0}" -gt "$xmax" ] && xmax=$p
    done <<<"$xrows"
  fi
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
  # 取得はできていても書き戻しだけ失敗しているケースがあるので出しておく
  [ -n "$claude_err" ] && echo "⚠️ $claude_err | color=red"
else
  exp_note=""
  [ "$exp_ms" -gt 0 ] && exp_note=" / 期限 $(date -r $((exp_ms/1000)) '+%m-%d %H:%M')"
  echo "⚠️ 取得失敗: ${claude_err:-原因不明}$exp_note | color=red"
fi

echo "---"

# ==== ドロップダウン: Codex =========================================
echo "Codex"
if [ "$codex_ok" = 1 ]; then
  while IFS='|' read -r w p r; do
    rem=""; [ "${r:-0}" -gt 0 ] && rem="  ↻$(fmt_dur $((r-now)))"
    col=$(clr "$p"); cp=""; [ -n "$col" ] && cp="| color=$col"
    printf -- "%s %-16s %3s%%%s %s\n" "$(sig "$p")" "$(win_label "$w")" "$p" "$rem" "$cp"
  done <<<"$xrows"
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
