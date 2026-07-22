#!/usr/bin/env bash
set -euo pipefail

# Copied from https://github.com/GordonBeeming/claude-statusline

INSTALL_DIR="${HOME}/.claude/scripts"

# ANSI colors
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
DIM='\033[2m'
RESET='\033[0m'

# --- Read stdin (session JSON) ---
stdin_data=$(cat)

# --- Extract all fields from JSON in one jq call (no eval) ---
# Fields are joined with \x1f (unit separator) rather than a tab: bash's
# `read` treats tab as IFS *whitespace* and silently collapses/strips empty
# fields around it, which would misalign every field after the first empty
# one. \x1f isn't whitespace, so empty fields (e.g. an absent five_hour_pct)
# round-trip correctly.
US=$'\x1f'
tsv_line=$(echo "$stdin_data" | jq -j --arg us "$US" '
  [
    (.workspace.current_dir // .cwd // ""),
    (.model.display_name // ""),
    (.model.id // ""),
    (.cost.total_cost_usd // 0),
    (.cost.total_duration_ms // 0),
    (.context_window.used_percentage // 0),
    (.context_window.context_window_size // 0),
    (.context_window.total_input_tokens // 0),
    (.context_window.total_output_tokens // 0),
    (.rate_limits.five_hour.used_percentage // ""),
    (.rate_limits.five_hour.resets_at // ""),
    (.effort.level // ""),
    (.thinking.enabled // false)
  ] | map(tostring) | join($us)
' 2>/dev/null || true)
if [[ -z "$tsv_line" ]]; then
  default_fields=("" "" "" 0 0 0 0 0 0 "" "" "" false)
  tsv_line=$(IFS="$US"; echo "${default_fields[*]}")
fi
IFS="$US" read -r cwd model_name model_id session_cost_usd duration_ms ctx_pct ctx_size \
  total_input total_output five_hour_pct five_hour_resets effort_level thinking_enabled \
  <<< "$tsv_line"

# --- Gate numeric fields before they hit bash arithmetic ---
# Values above come from Claude Code's own stdin JSON, but they still flow
# straight into (( )) / [[ -gt ]] expressions below; a string like
# `a[$(cmd)]` in bash arithmetic executes commands. Anything not a plain
# integer/decimal (or "null") is reset to a safe default rather than trusted.
validate_numeric() {
  local __name=$1 __default=$2 __val="${!1}"
  if [[ -n "$__val" && "$__val" != "null" && ! "$__val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    printf -v "$__name" '%s' "$__default"
  fi
}
validate_numeric session_cost_usd 0
validate_numeric duration_ms 0
validate_numeric ctx_pct 0
validate_numeric ctx_size 0
validate_numeric total_input 0
validate_numeric total_output 0
validate_numeric five_hour_pct ""
validate_numeric five_hour_resets ""

# --- Currency, FX rate, and daily cost (self-contained — no external CLI) ---
# Currency picked via STATUSLINE_CURRENCY (default USD). USD short-circuits the
# network entirely so $-only users incur zero overhead.
currency_code="${STATUSLINE_CURRENCY:-USD}"
currency_code=$(printf '%s' "$currency_code" | tr '[:lower:]' '[:upper:]')
# Validate — the code interpolates into a cache file path, so anything off the
# ISO 4217 shape (3 uppercase letters) gets rejected to keep a value like
# `../foo` from escaping the cache dir.
[[ "$currency_code" =~ ^[A-Z]{3}$ ]] || currency_code="USD"

case "$currency_code" in
  USD) currency_symbol='$'   ;;
  AUD) currency_symbol='A$'  ;;
  GBP) currency_symbol='£'   ;;
  EUR) currency_symbol='€'   ;;
  NZD) currency_symbol='NZ$' ;;
  CAD) currency_symbol='C$'  ;;
  JPY) currency_symbol='¥'   ;;
  *)   currency_symbol="${currency_code} " ;;
esac

currency_rate=1

# FX cache: ${INSTALL_DIR}/.fx-cache-<CCY> — first line is the rate, second
# line is the unix epoch when it was fetched. Refreshed at most every 24h; on
# fetch failure we keep using the stale value rather than spam the source.
fx_cache_file="${INSTALL_DIR}/.fx-cache-${currency_code}"
if [[ "$currency_code" != "USD" ]]; then
  fx_now=$(date +%s)
  fx_rate=""
  fx_ts=0
  if [[ -f "$fx_cache_file" ]]; then
    fx_rate=$(sed -n '1p' "$fx_cache_file" 2>/dev/null || echo "")
    fx_ts=$(sed -n '2p' "$fx_cache_file" 2>/dev/null || echo 0)
  fi
  # A corrupted/partial cache must not crash the render under `set -e`. The
  # rate is validated against a decimal-number shape; the timestamp against
  # an integer shape. Anything else is treated as cache-miss.
  [[ "$fx_rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] || fx_rate=""
  [[ "$fx_ts" =~ ^[0-9]+$ ]] || fx_ts=0
  fx_age=$(( fx_now - fx_ts ))
  if [[ -z "$fx_rate" || "$fx_age" -ge 86400 ]]; then
    fetched=$(curl -sSL --connect-timeout 2 --max-time 3 \
      "https://open.er-api.com/v6/latest/USD" 2>/dev/null \
      | jq -r --arg c "$currency_code" '.rates[$c] // empty' 2>/dev/null || true)
    if [[ -n "$fetched" && "$fetched" != "null" ]]; then
      mkdir -p "$INSTALL_DIR" 2>/dev/null || true
      printf '%s\n%s\n' "$fetched" "$fx_now" > "$fx_cache_file" 2>/dev/null || true
      fx_rate="$fetched"
    fi
  fi
  if [[ -n "$fx_rate" && "$fx_rate" != "null" ]]; then
    currency_rate="$fx_rate"
  else
    # No rate available (no cache + no network) — degrade to USD silently.
    currency_symbol='$'
  fi
fi

# Daily cost: today's USD spend across every project, derived from
# ~/.claude/projects/*/*.jsonl. Cached for 60s so the statusline isn't
# repeatedly scanning the transcript tree at typing speed. Cache busts on
# local date rollover.
daily_cost_usd=0
daily_cache_file="${INSTALL_DIR}/.daily-cost-cache"
today_local=$(date '+%Y-%m-%d')
need_recompute=true
if [[ -f "$daily_cache_file" ]]; then
  c_total=$(sed -n '1p' "$daily_cache_file" 2>/dev/null || echo "")
  c_ts=$(sed -n '2p' "$daily_cache_file" 2>/dev/null || echo 0)
  c_day=$(sed -n '3p' "$daily_cache_file" 2>/dev/null || echo "")
  # Treat any corrupt/non-numeric cache line as a miss — the script runs
  # under `set -e` so an arithmetic error here would abort the whole render.
  [[ "$c_ts" =~ ^[0-9]+$ ]] || c_ts=0
  [[ "$c_total" =~ ^[0-9]+(\.[0-9]+)?$ ]] || c_total=""
  # Carry today's last known total forward as a fallback so a transient
  # recompute failure (jq parse error, date parse failure) doesn't blank
  # out the daily display — the next successful recompute will refresh it.
  if [[ -n "$c_total" && "$c_day" == "$today_local" ]]; then
    daily_cost_usd="$c_total"
    if (( $(date +%s) - c_ts < 60 )); then
      need_recompute=false
    fi
  fi
fi
if [[ "$need_recompute" == "true" ]]; then
  # Local-day window expressed as UTC epoch bounds. BSD `date -j -f` (macOS)
  # and GNU `date -d` use incompatible syntax for parsing a date string —
  # try both so the script keeps working if anyone runs it on Linux. If
  # neither succeeds we skip the recompute entirely rather than silently
  # treating "epoch 0" as today (which would zero out the daily total).
  day_lo=$(date -j -f '%Y-%m-%d %H:%M:%S' "${today_local} 00:00:00" '+%s' 2>/dev/null \
    || date -d "${today_local} 00:00:00" '+%s' 2>/dev/null \
    || echo "")
  # recompute_ok stays false on any failure path (date parse failure, jq
  # parse error on a half-written .jsonl). Only a successful recompute
  # writes the cache — otherwise we'd clobber the last good value with 0
  # and silently suppress the daily display for the full 60s TTL.
  recompute_ok=false
  if [[ -n "$day_lo" ]]; then
    day_hi=$(( day_lo + 86400 ))
    # Sonnet 5 launched on introductory pricing ($2/$10) that reverts to the
    # standard $3/$15 on 2026-09-01. Gate on today's local date (ISO strings
    # compare lexicographically) so the table self-corrects at the cutover
    # without a manual edit — "2026-08-31" is the last introductory day.
    if [[ "$today_local" > "2026-08-31" ]]; then s5_std=true; else s5_std=false; fi
    projects_dir="${HOME}/.claude/projects"
    jsonl_files=()
    if [[ -d "$projects_dir" ]]; then
      # 26h window of mtimes catches anything that could still be writing
      # records inside today's local-time window.
      while IFS= read -r f; do
        [[ -n "$f" ]] && jsonl_files+=("$f")
      done < <(find "$projects_dir" -type f -name '*.jsonl' -mmin -1560 2>/dev/null)
    fi
    if (( ${#jsonl_files[@]} > 0 )); then
      # Pricing table — USD per 1M tokens. Source: https://www.anthropic.com/pricing
      # Fable 5 / Mythos 5 ($10/$50) are the top tier, above Opus. Mythos 5
      # (claude-mythos-5, Project Glasswing limited availability) shares Fable's
      # rate, so one branch covers both via the `fable|mythos` test. Their ids
      # have no `opus` substring, so ordering vs. the opus branches doesn't
      # matter for correctness — they sit first so the priciest tier is easy to
      # spot.
      # Opus 4.5+ is priced 1/3 of older Opus (4.1, 3) — Anthropic dropped the
      # rate for the newer models. The newer branch must be matched *before* the
      # generic `opus` fallback so it wins for `claude-opus-4-7-…` etc. Sonnet 5+
      # gets its own branch before the generic `sonnet` fallback because it
      # launched on introductory pricing ($2/$10) — a date gate (bash `s5_std`,
      # passed into jq as `$s5std`) swaps to the standard $3/$15 at the
      # 2026-09-01 cutover, while Sonnet 4.6 and earlier stay $3/$15 throughout. Haiku
      # 4.x is its own bucket ($1/$5 with 1h cache write $2 — note 2x not 2.5x).
      # Haiku 3.5 is matched before legacy Haiku 3 so `claude-3-5-haiku-…`
      # doesn't fall into the cheaper bucket. Any model with no row here returns
      # null and is dropped by the `select(model_rate(...) != null)` filter — so
      # an unpriced model silently *under-counts* the daily total (excluded, not
      # zero-weighted). Keep this table current when Anthropic ships or re-prices
      # a model, or that model's spend vanishes from the daily figure.
      # Dedupe by message.id|requestId — Claude Code transcripts re-emit the
      # same usage record multiple times (streaming progress events, session
      # resume rewrites). Without dedup the same tokens get billed N times,
      # inflating the daily total by 2–5x vs. tools like ccusage/goccc.
      # Records missing both IDs are passed through un-deduped so they aren't
      # collapsed into a single bucket (which would under-count).
      #
      # The `|| jq_exit=$?` is load-bearing: under `set -e` a non-zero exit
      # from the command substitution would otherwise abort the script before
      # we get a chance to handle the failure. With the `|| ...` guard the
      # exit code is captured and the next block falls back to the cached
      # value instead of crashing the render.
      jq_exit=0
      jq_raw=$(jq -n -r --argjson lo "$day_lo" --argjson hi "$day_hi" --argjson s5std "$s5_std" '
        def model_rate($m):
          ($m | ascii_downcase) as $lm
          | if   ($lm | test("fable|mythos"))             then {i:10,   o:50,   cw5:12.50,  cw1h:20,    cr:1.00}
            elif ($lm | test("opus-4-[5-9]|opus-[5-9]"))   then {i:5,    o:25,   cw5:6.25,   cw1h:10,    cr:0.50}
            elif ($lm | test("opus"))                      then {i:15,   o:75,   cw5:18.75,  cw1h:30,    cr:1.50}
            elif ($lm | test("sonnet-5|sonnet-[6-9]"))     then (if $s5std then {i:3, o:15, cw5:3.75, cw1h:6, cr:0.30}
                                                                          else {i:2, o:10, cw5:2.50, cw1h:4, cr:0.20} end)
            elif ($lm | test("sonnet"))                    then {i:3,    o:15,   cw5:3.75,   cw1h:6,     cr:0.30}
            elif ($lm | test("haiku-4|haiku-[5-9]"))       then {i:1,    o:5,    cw5:1.25,   cw1h:2,     cr:0.10}
            elif ($lm | test("3-5-haiku|haiku-3-5"))       then {i:0.80, o:4,    cw5:1,      cw1h:1.60,  cr:0.08}
            elif ($lm | test("3-haiku|haiku-3"))           then {i:0.25, o:1.25, cw5:0.3125, cw1h:0.50,  cr:0.025}
            elif ($lm | test("haiku"))                     then {i:1,    o:5,    cw5:1.25,   cw1h:2,     cr:0.10}
            else null end;
        [ inputs
          | select(.timestamp != null and (.message.usage // null) != null and (.message.model // null) != null)
          | (((.timestamp[0:19] + "Z") | fromdateiso8601?) // 0) as $ts
          | select($ts >= $lo and $ts < $hi)
          | select(model_rate(.message.model) != null)
        ]
        | (map(select((.message.id // "") != "" or (.requestId // "") != ""))
            | unique_by((.message.id // "") + "|" + (.requestId // "")))
          + map(select((.message.id // "") == "" and (.requestId // "") == ""))
        | .[]
        | model_rate(.message.model) as $r
        | .message.usage as $u
        | ((($u.input_tokens // 0)              * $r.i)
          + (($u.output_tokens // 0)            * $r.o)
          + (($u.cache_read_input_tokens // 0)  * $r.cr)
          + (if ($u.cache_creation // null) != null
               then (($u.cache_creation.ephemeral_5m_input_tokens // 0) * $r.cw5)
                  + (($u.cache_creation.ephemeral_1h_input_tokens // 0) * $r.cw1h)
               else (($u.cache_creation_input_tokens // 0) * $r.cw5)
             end)) / 1000000
      ' "${jsonl_files[@]}" 2>/dev/null) || jq_exit=$?
      if [[ "$jq_exit" -eq 0 ]]; then
        daily_cost_usd=$(printf '%s\n' "$jq_raw" | awk 'BEGIN{s=0} {s+=$1} END{printf "%.4f", s+0}')
        recompute_ok=true
      fi
    else
      # No transcript files to scan — legitimate zero, safe to cache.
      daily_cost_usd=0
      recompute_ok=true
    fi
  fi
  if [[ "$recompute_ok" == "true" ]]; then
    mkdir -p "$INSTALL_DIR" 2>/dev/null || true
    printf '%s\n%s\n%s\n' "$daily_cost_usd" "$(date +%s)" "$today_local" \
      > "$daily_cache_file" 2>/dev/null || true
  fi
fi

# --- Helper: format cost with color ---
# Session vs daily spending have very different distributions — sessions are
# usually small with a long tail; daily totals are the aggregate.
format_cost() {
  local cost=$1
  local kind=${2:-session}  # session | daily
  local yellow_at red_at
  case "$kind" in
    daily)  yellow_at=200; red_at=400 ;;
    *)      yellow_at=75;  red_at=150 ;;
  esac
  local formatted
  formatted=$(printf '%s%.2f' "$currency_symbol" "$cost")
  local cost_int=${cost%.*}
  if (( cost_int >= red_at )); then
    printf '%b%s%b' "$RED" "$formatted" "$RESET"
  elif (( cost_int >= yellow_at )); then
    printf '%b%s%b' "$YELLOW" "$formatted" "$RESET"
  else
    printf '%s' "$formatted"
  fi
}

# --- Helper: colored progress bar ---
make_bar() {
  local pct=$1
  local width=${2:-10}
  if (( pct > 100 )); then pct=100; fi
  if (( pct < 0 )); then pct=0; fi
  local filled=$(( pct * width / 100 ))
  local empty=$(( width - filled ))
  local bar_color
  if (( pct >= 90 )); then bar_color="$RED"
  elif (( pct >= 70 )); then bar_color="$YELLOW"
  else bar_color="$GREEN"; fi
  # Built via bash string repetition rather than `tr ' ' '█'`: GNU tr treats
  # multi-byte UTF-8 characters (█ is 3 bytes) as separate single-byte
  # elements regardless of locale, so it silently truncates SET2 down to
  # SET1's length and every space collapses to the block's lone first byte —
  # producing invalid UTF-8 that renders as "�" boxes.
  local bar="" i
  for (( i = 0; i < filled; i++ )); do bar+="█"; done
  for (( i = 0; i < empty; i++ )); do bar+="░"; done
  printf '%b%s%b' "$bar_color" "$bar" "$RESET"
}

# --- Get repo name ---
repo_name=""
in_git_repo=false
toplevel=""
if [[ -n "$cwd" ]]; then
  toplevel=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
fi
if [[ -z "$toplevel" && -z "$cwd" ]]; then
  toplevel=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
if [[ -n "$toplevel" ]]; then
  repo_name=$(basename "$toplevel")
  in_git_repo=true
elif [[ -n "$cwd" ]]; then
  # Fallback: not in a git repo, show the current folder name (handles paths with spaces)
  repo_name=$(basename "$cwd")
else
  # Fallback: cwd unset and not in a git repo, use the process working directory
  current_dir=$(pwd -P 2>/dev/null || pwd 2>/dev/null || true)
  [[ -n "$current_dir" ]] && repo_name=$(basename "$current_dir")
fi

# --- Get branch info ---
branch_info=""
current_branch=$(git branch --show-current 2>/dev/null || echo "")
if [[ -n "$current_branch" ]]; then
  truncated_branch="$current_branch"
  if (( ${#truncated_branch} > 24 )); then
    truncated_branch="${truncated_branch:0:23}…"
  fi
  branch_info="🔀 ${truncated_branch}"
fi

# --- Model display ---
model_display=""
if [[ -n "$model_name" ]]; then
  model_display="🤖 ${model_name}"
fi

# --- Effort level + thinking flag (merged into one field) ---
effort_display=""
if [[ -n "$effort_level" ]]; then
  case "$effort_level" in
    low)       effort_display=$(printf '⚡ %b%s%b' "$DIM" "$effort_level" "$RESET") ;;
    medium)    effort_display="⚡ ${effort_level}" ;;
    high)      effort_display=$(printf '⚡ %b%s%b' "$YELLOW" "$effort_level" "$RESET") ;;
    xhigh|max) effort_display=$(printf '⚡ %b%s%b' "$RED" "$effort_level" "$RESET") ;;
    *)         effort_display="⚡ ${effort_level}" ;;
  esac
fi
if [[ "$thinking_enabled" == "true" ]]; then
  if [[ -n "$effort_display" ]]; then
    effort_display="${effort_display} 🤔"
  else
    effort_display="🤔"
  fi
fi

# --- Session cost (convert USD to local currency) ---
session_cost_local=""
if [[ "$session_cost_usd" != "0" && "$session_cost_usd" != "null" ]]; then
  session_cost_val=$(echo "$session_cost_usd $currency_rate" | awk '{printf "%.2f", $1 * $2}')
  session_cost_local="💸 $(format_cost "$session_cost_val") session"
fi

# --- Daily cost (convert USD to local currency) ---
daily_cost_display=""
if [[ -n "$daily_cost_usd" && "$daily_cost_usd" != "0" && "$daily_cost_usd" != "0.0000" && "$daily_cost_usd" != "null" ]]; then
  daily_cost_val=$(echo "$daily_cost_usd $currency_rate" | awk '{printf "%.2f", $1 * $2}')
  daily_cost_display="💰 $(format_cost "$daily_cost_val" daily) today"
fi

# --- Rate limit bar ---
rate_display=""
if [[ -n "$five_hour_pct" && "$five_hour_pct" != "null" ]]; then
  pct_int=${five_hour_pct%.*}
  bar=$(make_bar "$pct_int" 10)
  time_left=""
  if [[ -n "$five_hour_resets" && "$five_hour_resets" != "null" ]]; then
    now=$(date +%s)
    remaining=$(( ${five_hour_resets%.*} - now ))
    if (( remaining > 0 )); then
      hours_left=$(( remaining / 3600 ))
      mins_left=$(( (remaining % 3600) / 60 ))
      time_left=" ${hours_left}h${mins_left}m left"
    fi
  fi
  rate_display="⏱️ ${bar} ${pct_int}%${time_left}"
elif [[ "$duration_ms" != "0" && "$duration_ms" != "null" ]]; then
  duration_secs=$(( ${duration_ms%.*} / 1000 ))
  # Only show duration if session has actually been running (> 0 seconds)
  if (( duration_secs > 0 )); then
    hours=$(( duration_secs / 3600 ))
    mins=$(( (duration_secs % 3600) / 60 ))
    rate_display="⏱️ ${hours}h${mins}m"
  fi
fi

# --- Context + tokens (hide when session hasn't started yet) ---
ctx_display=""
if [[ "$ctx_size" != "0" && "$ctx_size" != "null" ]]; then
  ctx_int=${ctx_pct%.*}
  # Only show context bar if there's actual usage
  if (( ctx_int > 0 )); then
    ctx_bar=$(make_bar "$ctx_int" 10)
    ctx_display="💭 ${ctx_bar} ${ctx_int}% ctx"
  fi
fi

tokens_in_display=""
tokens_out_display=""
if [[ "$total_input" != "0" && "$total_input" != "null" && "${total_input%.*}" -gt 0 ]]; then
  in_k=$(( ${total_input%.*} / 1000 ))
  out_k=$(( ${total_output%.*} / 1000 ))
  tokens_in_display="🧠 ${in_k}k in"
  tokens_out_display="${out_k}k out"
fi

# --- Build two-line output ---
# Line 1: folder, branch, model, thinking, session cost, daily cost, time-left
line1_parts=()
if [[ -n "$repo_name" ]]; then
  if [[ "$in_git_repo" == "true" ]]; then
    line1_parts+=("📂 ${repo_name}")
  else
    line1_parts+=("📁 ${repo_name}")
    line1_parts+=("$(printf '%b🚫 no git%b' "$DIM" "$RESET")")
  fi
fi
[[ -n "$branch_info" ]] && line1_parts+=("$branch_info")
[[ -n "$model_display" ]] && line1_parts+=("$model_display")
[[ -n "$effort_display" ]] && line1_parts+=("$effort_display")
[[ -n "$session_cost_local" ]] && line1_parts+=("$session_cost_local")
[[ -n "$daily_cost_display" ]] && line1_parts+=("$daily_cost_display")
[[ -n "$rate_display" ]] && line1_parts+=("$rate_display")

# Line 2: context, tokens in, tokens out
line2_parts=()
[[ -n "$ctx_display" ]] && line2_parts+=("$ctx_display")
[[ -n "$tokens_in_display" ]] && line2_parts+=("$tokens_in_display")
[[ -n "$tokens_out_display" ]] && line2_parts+=("$tokens_out_display")

# Join parts within each line
join_parts() {
  local sep=" | "
  local result=""
  for part in "$@"; do
    if [[ -n "$result" ]]; then
      result="${result}${sep}${part}"
    else
      result="$part"
    fi
  done
  echo "$result"
}

output=""
if (( ${#line1_parts[@]} > 0 )); then
  output+=$(join_parts "${line1_parts[@]}")
fi
if (( ${#line2_parts[@]} > 0 )); then
  [[ -n "$output" ]] && output+=$'\n'
  output+=$(join_parts "${line2_parts[@]}")
fi

echo -e "$output"
