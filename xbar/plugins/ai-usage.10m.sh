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

# --- アイコン (ローカルアプリから生成したモノクロ template 画像) ------
IMG_CLAUDE="iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAADN0lEQVR4nO2XWYjNURzHP/97LzMMhewebGUposj2YhcPXrxYEslSSkqWNE3KgzWJyODBg5IMnj0oaSKTrVGWmDHZEobBjJ2Zq199T/36Nzfj3sso86vTOed3zvmf7289vz+00X9Akdo/QVGGcaCE2l+lfkBPjVtNUwn1s4B6oA6YKEBJB2wLcBRo70xrZ1P51lxK/WEgrXY6tjbUrY2NreWNImkgSDwHaAIagU/AMKeduVp7A/R1/EHAdmCk5nnTVKSPnXWa2OvWF4t3SwIYDQaqxb8BFGQbpeFAV+AgsBXoIN5woEHaeA0M0P61urhM817AHfG+A9eAdtkCMjMZzXPauCIwRjsdf594uzQv0fy85l9k4hm5mCxyUl53lz+Xr5ikT8SzqOuj6LL5VGCzxp/Vb4oJmhV5s4XLQisGlgFfNd8BnJI2NgI/gG+xaGwvQZLZAgtOHGgh8MiBKgeeyZeeynkNxAfxbE8N0I0/QCn15sAnHahwcbw1Ctg4nRsIzARWA6UKkgIneIvIDoT8E6fpwE1d3BQD1qj+kSK0Uqb0gN8DXZoDFL8s0oEeurBAof0OeKtw/6Bw7gys0d70LyS1s/cFzr57CbjX3MZMqd0AnAAmAEVAd6A/0FH5qEARFxKgBxPA2Xt3BrgA3AVeALXkiRKKkELNC+XkL2Nm8r5VK41+VHsFPACuAiuySZD+FfdhOkaSp2W++pj/hFaqiy3sHzYTAJa7yCZrJ9SbyQ45bVgm3q9cVKfnIWgnXG6AkJlHAEuBA8D8XHKR0QLgsS6xpLceGCW/qAJ2K5Iua0+DtJLWWl4oSFDi1HxRucWC4bZ404BtGo9WkjTQR4Bj4pe6UiaVrXaCqTYAFcA6F5VlsfKjXBoyWqk1c+QpqiJDFVCk7+Zc+ibduFgXVCj8OynPVLs0EF76KkXkolhlkFMlGUkqAzVbH36ikhWVq+FtC5E5RJWj8fdo33hgsvtmzoAilSLv5CthbbGiyl57L/0SATr3Oz7TEtWlXb9BuadS5rKQnyRg9W6fzY/rzapRqki6tJB3Sjipl8uBV2me/Jv/bIkMJWjvDPuTrfEn+09S1NoA2ojWop9sdvmxUbM2OgAAAABJRU5ErkJggg=="
IMG_CODEX="iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAEw0lEQVR4nO2YeWhcVRSHv0wmabYmjcYYFG21lrqhoFbrglIRREVxKUrrihQXqv4hCFpwwwUVFBdEKqgI4lKXoqBVQQWpSwWtuKaSooh7bU1sqzFtMnLgu3D7nJmM/a/QA4+Zee+ee875nd85576BnbKDSVMDa0rZZyXTqzSwd75+wu8T2+tQOJA2rbvJ/5BJ96zlUFmFiSrrmrzGq+g1V0GuUuV7yWtrIw6VVQyDRQO5I3sA+wHdwAgwBPycrauoXzKwPH1p76aiU2G8KLHBWOZMU2GjTuB8YA4wCvwNdACtwIfA894r+3xc3bRfcnRcnboItbpwooBOU/b8BmB34Dngc42P62A4usn1LcAwsAp4E/jHexNZcCXtjNVCKD0sF/jSbLQXA9OBm4FvM72ZwLEa+wn4XgdmAAuAecBdwLrMqWbT9R+Ucmn3s8WrVcWQPYFngTOz9f3A1cALGjyiyp77AkuBB4E2g0375zarSkeWmilC2q7R4MZTRh33zwCeAR4HTskM9AEnaTxJ6LwKnO3vtgyZZLMmqdFg5DgW36uR1cBBwJ9udiHwKfCwXIm95gPnAr2m6glgJfAd8IGOLi8UC406FJy5DpglWQP6YzKiVyTssPxZCAwAr+j8OcAdwCfAfTp/pEGmKm7YoaicvYHTgXvsL4dnYyQRPZydC5wMbAHWAG8AvwCfAccBl4lUkH1DVl01kagmEf1hGnkvm0UtWamOmrZI4xLgRpvkMmCx3yNdlwOPAXsBXVmV1XQql5xgi4w2GmHIacDbrumUpEskaCkrgOuBL4DXJXHiyv7A+8At/u6qYrOulwFvrwolIxtwXGy2CodEaqpXpHot8KPIRr960j41CNwvt6a7dtKUpWhaJGYXcIIQfwV8BDxtelL7T3p51QRqt4tycOxQn78roecUdCdFqN1O/KLGo498A1wJ3Gn57gMc6B7DXrH5wX52isoGO3LFsRLo7kaDkvgyVad6gbdEZ0EWTcyya4EvgdeAo4Cj5VwEskJS91vuZ6nbL7/Oq2KzLkKYki3OpDByk8ajF/1qb5ln1Mvt2uHgo0BPduRolgIV10ewH8vBhjmUzjPlbIadCmwEXrI7HwJcBBxg9SwWtUE5lBpoi30puv3djqC12Qyre4wO7xHuiLJs+T7i/Q6b5UpRilRe5fr0fKlIdZvaSNlDHlVW6FiX++c2q0rqDbF4F72/QuMz/N0qFxbaApLM13iQ/1KRmWX3HhKdPjkzLXOoqxGEelTq9vMd8x7jpChzJfMfIjEzI2qMjR+A2QbTbaH01EKoOMvSjEqvPGVJvch5tMqT4mrTEwQ/3hSe6P0p6kRbuM3jyRpLPZV/fvDbhkNFQnW6KM2tSja3goQXWMID3ms2DdcAL2fjI6rpAeBr28XWwnsdVnA65myu5VDIrsB6Pye8l94cNopAT3bUjTP2JTbGdaa41yF7K/BXNlDJ9ks21tdDKOW0ZH+ZVjjoJ8fSEWLc9MyWS0H233z7GBStaq9SI2YjBVnXIYwwIN2UlX/x1TjfY9Qr8aMt60XpXsXUjWTHkCiEbaReUwp0Sjo25lWZ5BU5SfFVObWL1ix9keLt+rOhr2CwSM56kv/JkJz8vUHdnbJjyL/6dC66jurOaQAAAABJRU5ErkJggg=="
IMG_COPILOT="iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAD/ElEQVR4nO2YTYtcVRCGn+7bHSeZZCbzZRTRgKJGNC4iooKKK8EPBN0oioJggi78BwEXutGdIojgQlEQQUQQFI0rFRXEjVko8SOKIKSTtBpnJp30dF858BScjH277wguNBZc7pl7zql66606daoH/pd/mTT+AR0lZ6s0fBc1mW24Nt9b28hG1pa+rwL2AJcA2/32K/Ad8CXwdcW+vw0on2sCA8d3AA8Cu4EtGiqzPelZAb4CXgHed65Qx1iAVYBCcYBZA84FngRuBfrAKjBktDQF2wLeA54Ajvl37MkdmQioyBT3gYuBl3wfy/KjOUJpQ6PB6CJwCNgL/Ai0M1CDuoBazg1U+AawEzgBzDjf82lnDgx0YDNwjsymPbPAD8C95lk4slYXUNu5PvAicDvQ1fBTGrsfuBQ4Ciy7bxpYkpHXgdPAfoEuAO8Aj6m/VH8tSR4mSQn8C3AQ+B74RDBJ5oEbgPOAbT47gGuBOddMAZ968g6q67Z1Ns6QZgVjpWF5xHhHCKcEkkD9AXwmQxG+lF9feMo2ycpm90ZC73Wcn8xKQCG9rM70VNCS+oGK256kTYaycBynK3Kk79rIuz3q7tVhKJfrDEOpF1uBV4GODI2qP8Fu6ZojwMvubfg9HYrrq4wm1FWyS8Dh/Yo51NxAlW+6Z0WWBn67fNyGKknxb7imLcW/Z040JjzhcDr2Jw1n2FuscqgKUF74Cr9ttZ6Ufp8EKGrNrKEnY7u5UUClnrUyxeko35gl6SRAbdfe5N6huoK14UaOPdaOImNp2aJ2kdU2Ttd6IC3nulb3xw1ZOFdYtUfZrASYvLtZTzq++zL1EXBFFoIZwzLrOHRcDXxuQh+xRoWuWwQ9LkpnTM4Z948t/x8C99lKJFCHgaeBu0zQ7QJK18Y9wHOCWBVE1wK6ajGdzap5LUBLev+wxe0nwzUlQ1FrnjfZF3xSUXzNueOy0vXpZJW60EbtkIWBaeDdLMkvA84HngUeFeCcaxe9JnZnrHTNt46OHZD50F+boQU92GYROySot2QkJIDEO4G7wPZ1WZY6JnVi+Up1LmWAxt5lpV7HUd8C/Aw8AHwL3A18YAvyjCDW1tUlsvtuzcu4Y7tyOGt7myb2xF57RiXJiyVDNC1Tb2f5k4xeY4LusMVNXl9oyYiL+IBhnFZX6J1fx3blXdbLeuihSmf08iHgTmCfiXncEhHUF4bnG3PuBeDN7FKNlrUw4f+SP1UZnrxJErd9Ht7fnE+hPaXynPahocjb1+izQ88J50/VBdTIlM5n91npeJhdBaOa/GhZ4qdPyMCTF+ORhqskLsgpx6ez/Kn74y/WhoOlxXGs0brSHHNLl2P+DifO3n9C/LflTzwLBS4WzomwAAAAAElFTkSuQmCC"
IMG_STRIP="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"
# --------------------------------------------------------------------

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
# 先頭の templateImage (アイコン帯) が C/X/G の順に対応するので文字の識別子は付けない
if [ "$claude_ok" = 1 ]; then c_seg="$(sig "$cmax")${cmax}%"; else c_seg="⚠️"; fi
if [ "$codex_ok"  = 1 ]; then x_seg="$(sig "$xmax")${xmax}%"; else x_seg="⚠️"; fi
if [ "$cop_ok"    = 1 ]; then
  g_seg="$(sig "$gmax")${gmax}%"
else g_seg="⚠️"; fi

overall=$(( cmax > xmax ? cmax : xmax ))
overall=$(( overall > gmax ? overall : gmax ))
line_color=""
lc=$(clr "$overall"); [ -n "$lc" ] && line_color=" color=$lc"
echo "$c_seg $x_seg $g_seg | templateImage=$IMG_STRIP$line_color"

echo "---"

# ==== ドロップダウン: Claude ========================================
echo "Claude Code | templateImage=$IMG_CLAUDE href=https://claude.ai/settings/usage"
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
echo "Codex | templateImage=$IMG_CODEX"
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
echo "GitHub Copilot | templateImage=$IMG_COPILOT href=https://github.com/settings/copilot"
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
