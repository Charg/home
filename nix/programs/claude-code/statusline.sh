#!/usr/bin/env bash
set -euo pipefail

# Copied from https://github.com/GordonBeeming/claude-statusline
#
# Runs on every render, so the warm path avoids forks: dates via printf
# %()T, cache files via `read`, string ops via parameter expansion. Requires
# bash >= 4.2 (nix bash, not macOS /bin/bash 3.2).

INSTALL_DIR="${HOME}/.claude/scripts"

# ANSI colors
RED='\033[31m'
YELLOW='\033[33m'
GREEN='\033[32m'
DIM='\033[2m'
RESET='\033[0m'

printf -v now '%(%s)T' -1

# --- Extract all fields from stdin session JSON in one jq call (no eval) ---
# Fields are joined with \x1f (unit separator) rather than a tab: bash's
# `read` treats tab as IFS *whitespace* and silently collapses/strips empty
# fields around it, which would misalign every field after the first empty
# one. \x1f isn't whitespace, so empty fields (e.g. an absent five_hour_pct)
# round-trip correctly.
US=$'\x1f'
tsv_line=$(jq -j --arg us "$US" '
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
    (.thinking.enabled // false),
    (.transcript_path // "")
  ] | map(tostring) | join($us)
' 2>/dev/null || true)
if [[ -z "$tsv_line" ]]; then
  default_fields=("" "" "" 0 0 0 0 0 0 "" "" "" false "")
  tsv_line=$(IFS="$US"; echo "${default_fields[*]}")
fi
IFS="$US" read -r cwd model_name model_id session_cost_usd duration_ms ctx_pct ctx_size \
  total_input total_output five_hour_pct five_hour_resets effort_level thinking_enabled \
  transcript_path <<< "$tsv_line"

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

ensure_install_dir() {
  [[ -d "$INSTALL_DIR" ]] || mkdir -p "$INSTALL_DIR" 2>/dev/null || true
}

# --- Session cache tokens (main transcript only; subagents live in other files) ---
# Path must sit under ~/.claude/projects and contain no `..` segments.
# Cached per session; reparsed only when the transcript is newer than the
# stamp, which is touched *before* parsing so appends mid-parse aren't missed.
cache_read=0
cache_write=0
case "$transcript_path" in
  "${HOME}/.claude/projects/"*.jsonl)
    if [[ "$transcript_path" != *"/../"* && -r "$transcript_path" ]]; then
      session_cache_dir="${INSTALL_DIR}/.session-cache"
      session_cache="${session_cache_dir}/${transcript_path##*/}"
      if [[ -f "$session_cache" && -f "${session_cache}.stamp" \
            && ! "$transcript_path" -nt "${session_cache}.stamp" ]]; then
        read -r cache_read cache_write < "$session_cache" || true
      else
        [[ -d "$session_cache_dir" ]] || mkdir -p "$session_cache_dir" 2>/dev/null || true
        : > "${session_cache}.stamp" 2>/dev/null || true
        cache_line=$(jq -n -r '
          [ inputs | select((.message.usage // null) != null) ]
          | (map(select((.message.id // "") != "" or (.requestId // "") != ""))
              | unique_by((.message.id // "") + "|" + (.requestId // "")))
            + map(select((.message.id // "") == "" and (.requestId // "") == ""))
          | map(.message.usage)
          | "\(map(.cache_read_input_tokens // 0) | add // 0) \(map(.cache_creation_input_tokens // 0) | add // 0)"
        ' "$transcript_path" 2>/dev/null || true)
        read -r cache_read cache_write <<< "$cache_line" || true
        if [[ -n "$cache_line" ]]; then
          printf '%s\n' "$cache_line" > "$session_cache" 2>/dev/null || true
        else
          rm -f "${session_cache}.stamp" 2>/dev/null || true
        fi
      fi
    fi
    ;;
esac
validate_numeric cache_read 0
validate_numeric cache_write 0
[[ -n "$cache_read" ]] || cache_read=0
[[ -n "$cache_write" ]] || cache_write=0

# --- Currency, FX rate, and daily cost (self-contained — no external CLI) ---
# Currency picked via STATUSLINE_CURRENCY (default USD). USD short-circuits the
# network entirely so $-only users incur zero overhead.
currency_code="${STATUSLINE_CURRENCY:-USD}"
currency_code="${currency_code^^}"
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
  fx_rate=""
  fx_ts=0
  if [[ -f "$fx_cache_file" ]]; then
    { read -r fx_rate; read -r fx_ts; } < "$fx_cache_file" 2>/dev/null || true
  fi
  # A corrupted/partial cache must not crash the render under `set -e`. The
  # rate is validated against a decimal-number shape; the timestamp against
  # an integer shape. Anything else is treated as cache-miss.
  [[ "$fx_rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] || fx_rate=""
  [[ "$fx_ts" =~ ^[0-9]+$ ]] || fx_ts=0
  fx_age=$(( now - fx_ts ))
  if [[ -z "$fx_rate" || "$fx_age" -ge 86400 ]]; then
    fetched=$(curl -sSL --connect-timeout 2 --max-time 3 \
      "https://open.er-api.com/v6/latest/USD" 2>/dev/null \
      | jq -r --arg c "$currency_code" '.rates[$c] // empty' 2>/dev/null || true)
    if [[ -n "$fetched" && "$fetched" != "null" ]]; then
      ensure_install_dir
      printf '%s\n%s\n' "$fetched" "$now" > "$fx_cache_file" 2>/dev/null || true
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

# Daily + weekly (Mon-start) USD spend from ~/.claude/projects/*/*.jsonl.
# Cached 60s / 300s; each cache busts on day / week rollover.
printf -v today_local '%(%Y-%m-%d)T' "$now"

# Pricing — USD per 1M tokens (https://platform.claude.com/docs/en/about-claude/pricing).
# First match wins, so specific ids sit above their family fallback.
# Unmatched models are dropped (under-counted), so keep this current.
# Dedupe by message.id|requestId: transcripts re-emit the same usage record.
# One pass serves both windows; each is filtered then deduped on its own, so
# the result matches separate per-window passes. Empty window: lo == hi.
COST_JQ='
  def model_rate($m):
    ($m | ascii_downcase) as $lm
    | if   ($lm | test("(fable|mythos)-5-[1-9]([^0-9]|$)")) then {i:10, o:50, cw5:12.50, cw1h:20, cr:0.25}
      elif ($lm | test("fable|mythos"))             then {i:10,   o:50,   cw5:12.50,  cw1h:20,    cr:1.00}
      elif ($lm | test("opus-5-5"))                  then {i:4,    o:20,   cw5:5,      cw1h:8,     cr:0.20}
      elif ($lm | test("opus-4-[5-9]|opus-[5-9]"))   then {i:5,    o:25,   cw5:6.25,   cw1h:10,    cr:0.50}
      elif ($lm | test("opus"))                      then {i:15,   o:75,   cw5:18.75,  cw1h:30,    cr:1.50}
      elif ($lm | test("sonnet-5|sonnet-[6-9]"))     then {i:2,    o:10,   cw5:2.50,   cw1h:4,     cr:0.20}
      elif ($lm | test("sonnet"))                    then {i:3,    o:15,   cw5:3.75,   cw1h:6,     cr:0.30}
      elif ($lm | test("haiku-4|haiku-[5-9]"))       then {i:1,    o:5,    cw5:1.25,   cw1h:2,     cr:0.10}
      elif ($lm | test("3-5-haiku|haiku-3-5"))       then {i:0.80, o:4,    cw5:1,      cw1h:1.60,  cr:0.08}
      elif ($lm | test("3-haiku|haiku-3"))           then {i:0.25, o:1.25, cw5:0.3125, cw1h:0.50,  cr:0.025}
      elif ($lm | test("haiku"))                     then {i:1,    o:5,    cw5:1.25,   cw1h:2,     cr:0.10}
      else null end;
  def cost:
    .r as $r | .u as $u
    | ((($u.input_tokens // 0)              * $r.i)
      + (($u.output_tokens // 0)            * $r.o)
      + (($u.cache_read_input_tokens // 0)  * $r.cr)
      + (if ($u.cache_creation // null) != null
           then (($u.cache_creation.ephemeral_5m_input_tokens // 0) * $r.cw5)
              + (($u.cache_creation.ephemeral_1h_input_tokens // 0) * $r.cw1h)
           else (($u.cache_creation_input_tokens // 0) * $r.cw5)
         end)) / 1000000;
  def window_sum($lo; $hi):
    map(select(.ts >= $lo and .ts < $hi))
    | (map(select(.k != "|")) | unique_by(.k)) + map(select(.k == "|"))
    | map(cost) | add // 0;
  [ inputs
      | select(.timestamp != null and (.message.usage // null) != null and (.message.model // null) != null)
      | (((.timestamp[0:19] + "Z") | fromdateiso8601?) // 0) as $ts
      | select(($ts >= $day_lo and $ts < $day_hi) or ($ts >= $week_lo and $ts < $week_hi))
      | model_rate(.message.model) as $r
      | select($r != null)
      | {ts: $ts, r: $r, u: .message.usage, k: ((.message.id // "") + "|" + (.requestId // ""))}
    ]
  | "\(window_sum($day_lo; $day_hi)) \(window_sum($week_lo; $week_hi))"
'

# Local midnight of YYYY-MM-DD as epoch (BSD, then GNU date). Empty on failure.
local_midnight_epoch() {
  date -j -f '%Y-%m-%d %H:%M:%S' "$1 00:00:00" '+%s' 2>/dev/null \
    || date -d "$1 00:00:00" '+%s' 2>/dev/null \
    || true
}

# Cache format: total, fetch epoch, window key. Sets <prefix>_cost_usd if the
# key matches (stale fallback) and <prefix>_need=false if also within ttl.
read_cost_cache() {
  local file=$1 key=$2 ttl=$3 prefix=$4 c_total="" c_ts=0 c_key=""
  printf -v "${prefix}_need" '%s' true
  [[ -f "$file" ]] || return 0
  { read -r c_total; read -r c_ts; read -r c_key; } < "$file" 2>/dev/null || true
  # Corrupt lines = miss; bad arithmetic would abort under `set -e`.
  [[ "$c_ts" =~ ^[0-9]+$ ]] || c_ts=0
  [[ "$c_total" =~ ^[0-9]+(\.[0-9]+)?$ ]] || c_total=""
  if [[ -n "$c_total" && "$c_key" == "$key" ]]; then
    printf -v "${prefix}_cost_usd" '%s' "$c_total"
    if (( now - c_ts < ttl )); then
      printf -v "${prefix}_need" '%s' false
    fi
  fi
}

write_cost_cache() {
  ensure_install_dir
  printf '%s\n%s\n%s\n' "$2" "$now" "$3" > "$1" 2>/dev/null || true
}

daily_cost_usd=0
daily_cache_file="${INSTALL_DIR}/.daily-cost-cache"
read_cost_cache "$daily_cache_file" "$today_local" 60 daily

# Week start: step back from ~noon today so a DST shift can't change the date.
week_cost_usd=0
week_need=false
weekly_cache_file="${INSTALL_DIR}/.weekly-cost-cache"
printf -v now_hms '%(%u %H %M %S)T' "$now"
read -r dow hh mm ss <<< "$now_hms"
days_back=$(( dow - 1 ))
week_anchor=$(( now - (10#$hh * 3600 + 10#$mm * 60 + 10#$ss) + 43200 - days_back * 86400 ))
printf -v week_start_local '%(%Y-%m-%d)T' "$week_anchor"
[[ "$week_start_local" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || week_start_local=""
if [[ -n "$week_start_local" ]]; then
  read_cost_cache "$weekly_cache_file" "$week_start_local" 300 week
fi

# Refresh stale windows in one jq pass. Only cache on success so a failure
# doesn't write 0.
if [[ "$daily_need" == "true" || "$week_need" == "true" ]]; then
  day_lo=0; day_hi=0; week_lo=0; week_hi=0; mmin=0
  if [[ "$daily_need" == "true" ]]; then
    day_lo=$(local_midnight_epoch "$today_local")
    if [[ -n "$day_lo" ]]; then
      day_hi=$(( day_lo + 86400 ))
      mmin=1560  # 26h mtime window
    else
      day_lo=0; daily_need=false
    fi
  fi
  if [[ "$week_need" == "true" ]]; then
    week_lo=$(local_midnight_epoch "$week_start_local")
    if [[ -n "$week_lo" ]]; then
      week_hi=$(( now + 86400 ))
      # mtime window: week so far + 2h buffer.
      week_mmin=$(( (now - week_lo) / 60 + 120 ))
      (( week_mmin > mmin )) && mmin=$week_mmin
    else
      week_lo=0; week_need=false
    fi
  fi
  if (( mmin > 0 )); then
    projects_dir="${HOME}/.claude/projects"
    files=()
    if [[ -d "$projects_dir" ]]; then
      while IFS= read -r f; do
        [[ -n "$f" ]] && files+=("$f")
      done < <(find "$projects_dir" -type f -name '*.jsonl' -mmin "-${mmin}" 2>/dev/null)
    fi
    # No files → "0", else 4dp (matches the old per-window output).
    sums=""
    sum_fmt='%.4f'
    if (( ${#files[@]} == 0 )); then
      sums="0 0"; sum_fmt='%s'
    else
      sums=$(jq -n -r --argjson day_lo "$day_lo" --argjson day_hi "$day_hi" \
        --argjson week_lo "$week_lo" --argjson week_hi "$week_hi" \
        "$COST_JQ" "${files[@]}" 2>/dev/null) || sums=""
    fi
    if [[ -n "$sums" ]]; then
      read -r day_sum week_sum <<< "$sums"
      if [[ "$daily_need" == "true" ]]; then
        printf -v daily_cost_usd "$sum_fmt" "$day_sum"
        write_cost_cache "$daily_cache_file" "$daily_cost_usd" "$today_local"
      fi
      if [[ "$week_need" == "true" ]]; then
        printf -v week_cost_usd "$sum_fmt" "$week_sum"
        write_cost_cache "$weekly_cache_file" "$week_cost_usd" "$week_start_local"
      fi
    fi
  fi
fi

# --- Helper: format cost with color into variable $1 ---
# Session vs daily vs weekly spending have very different distributions — sessions are
# usually small with a long tail; daily totals are the aggregate.
format_cost() {
  local __out=$1 cost=$2
  local kind=${3:-session}  # session | daily | weekly
  local yellow_at red_at
  case "$kind" in
    daily)  yellow_at=200; red_at=400 ;;
    weekly) yellow_at=1000; red_at=2000 ;;
    *)      yellow_at=75;  red_at=150 ;;
  esac
  local formatted
  printf -v formatted '%s%.2f' "$currency_symbol" "$cost"
  local cost_int=${cost%.*}
  if (( cost_int >= red_at )); then
    printf -v "$__out" '%b%s%b' "$RED" "$formatted" "$RESET"
  elif (( cost_int >= yellow_at )); then
    printf -v "$__out" '%b%s%b' "$YELLOW" "$formatted" "$RESET"
  else
    printf -v "$__out" '%s' "$formatted"
  fi
}

# --- Helper: colored progress bar into variable $1 ---
make_bar() {
  local __out=$1 pct=$2
  local width=${3:-10}
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
  local __bar="" i
  for (( i = 0; i < filled; i++ )); do __bar+="█"; done
  for (( i = 0; i < empty; i++ )); do __bar+="░"; done
  printf -v "$__out" '%b%s%b' "$bar_color" "$__bar" "$RESET"
}

# --- Repo name + branch (one git call; branch read from HEAD like `git branch --show-current`) ---
repo_name=""
in_git_repo=false
toplevel=""
current_branch=""
git_args=()
[[ -n "$cwd" ]] && git_args=(-C "$cwd")
git_info=$(git "${git_args[@]}" rev-parse --show-toplevel --absolute-git-dir 2>/dev/null || true)
if [[ -n "$git_info" ]]; then
  { read -r toplevel; read -r git_dir; } <<< "$git_info" || true
  head_ref=""
  [[ -n "${git_dir:-}" && -r "${git_dir}/HEAD" ]] && { read -r head_ref < "${git_dir}/HEAD" || true; }
  [[ "$head_ref" == "ref: refs/heads/"* ]] && current_branch="${head_ref#ref: refs/heads/}"
fi
if [[ -n "$toplevel" ]]; then
  repo_name="${toplevel##*/}"
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
    low)       printf -v effort_display '⚡ %b%s%b' "$DIM" "$effort_level" "$RESET" ;;
    medium)    effort_display="⚡ ${effort_level}" ;;
    high)      printf -v effort_display '⚡ %b%s%b' "$YELLOW" "$effort_level" "$RESET" ;;
    xhigh|max) printf -v effort_display '⚡ %b%s%b' "$RED" "$effort_level" "$RESET" ;;
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

# --- Convert USD to local currency (no awk fork for USD) into variable $1 ---
to_local() {
  if [[ "$currency_rate" == "1" ]]; then
    printf -v "$1" '%.2f' "$2"
  else
    printf -v "$1" '%s' "$(awk -v a="$2" -v b="$currency_rate" 'BEGIN{printf "%.2f", a * b}')"
  fi
}

# --- Session cost ---
session_cost_local=""
if [[ "$session_cost_usd" != "0" && "$session_cost_usd" != "null" ]]; then
  to_local session_cost_val "$session_cost_usd"
  format_cost fc "$session_cost_val"
  session_cost_local="💸 ${fc} session"
fi

# --- Daily cost ---
daily_cost_display=""
if [[ -n "$daily_cost_usd" && "$daily_cost_usd" != "0" && "$daily_cost_usd" != "0.0000" && "$daily_cost_usd" != "null" ]]; then
  to_local daily_cost_val "$daily_cost_usd"
  format_cost fc "$daily_cost_val" daily
  daily_cost_display="💰 ${fc} today"
fi

# --- Weekly cost ---
week_cost_display=""
if [[ -n "$week_cost_usd" && "$week_cost_usd" != "0" && "$week_cost_usd" != "0.0000" && "$week_cost_usd" != "null" ]]; then
  to_local week_cost_val "$week_cost_usd"
  format_cost fc "$week_cost_val" weekly
  week_cost_display="🤑 ${fc} week"
fi

# --- Rate limit bar ---
rate_display=""
if [[ -n "$five_hour_pct" && "$five_hour_pct" != "null" ]]; then
  pct_int=${five_hour_pct%.*}
  make_bar bar "$pct_int" 10
  time_left=""
  if [[ -n "$five_hour_resets" && "$five_hour_resets" != "null" ]]; then
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
    make_bar ctx_bar "$ctx_int" 10
    ctx_display="💭 ${ctx_bar} ${ctx_int}% ctx"
  fi
fi

# Token count → 352 | 45k | 1.2M, into variable $1
fmt_tokens() {
  local __out=$1 n=${2%.*} frac
  if (( n >= 1000000 )); then
    printf -v frac '%06d' $(( n % 1000000 ))
    printf -v "$__out" '%.1fM' "$(( n / 1000000 )).${frac}"
  elif (( n >= 1000 )); then
    printf -v "$__out" '%dk' $(( n / 1000 ))
  else
    printf -v "$__out" '%d' "$n"
  fi
}

tokens_in_display=""
tokens_out_display=""
if [[ "$total_input" != "0" && "$total_input" != "null" && "${total_input%.*}" -gt 0 ]]; then
  fmt_tokens t_in "$total_input"
  fmt_tokens t_out "${total_output:-0}"
  tokens_in_display="🧠 ${t_in} in"
  tokens_out_display="${t_out} out"
fi

tokens_cache_display=""
if (( ${cache_read%.*} > 0 || ${cache_write%.*} > 0 )); then
  fmt_tokens t_cr "$cache_read"
  fmt_tokens t_cw "$cache_write"
  tokens_cache_display="♻️ ${t_cr} read / ${t_cw} write"
fi

# --- Build two-line output ---
# Line 1: folder, branch, model, thinking, session cost, daily cost, weekly cost, time-left
line1_parts=()
if [[ -n "$repo_name" ]]; then
  if [[ "$in_git_repo" == "true" ]]; then
    line1_parts+=("📂 ${repo_name}")
  else
    line1_parts+=("📁 ${repo_name}")
    printf -v no_git '%b🚫 no git%b' "$DIM" "$RESET"
    line1_parts+=("$no_git")
  fi
fi
[[ -n "$branch_info" ]] && line1_parts+=("$branch_info")
[[ -n "$model_display" ]] && line1_parts+=("$model_display")
[[ -n "$effort_display" ]] && line1_parts+=("$effort_display")
[[ -n "$session_cost_local" ]] && line1_parts+=("$session_cost_local")
[[ -n "$daily_cost_display" ]] && line1_parts+=("$daily_cost_display")
[[ -n "$week_cost_display" ]] && line1_parts+=("$week_cost_display")
[[ -n "$rate_display" ]] && line1_parts+=("$rate_display")

# Line 2: context, tokens in, tokens out, cache read/write
line2_parts=()
[[ -n "$ctx_display" ]] && line2_parts+=("$ctx_display")
[[ -n "$tokens_in_display" ]] && line2_parts+=("$tokens_in_display")
[[ -n "$tokens_out_display" ]] && line2_parts+=("$tokens_out_display")
[[ -n "$tokens_cache_display" ]] && line2_parts+=("$tokens_cache_display")

# Join parts with " | " into variable $1
join_parts() {
  local __out=$1 result="" part
  shift
  for part in "$@"; do
    result+="${result:+ | }${part}"
  done
  printf -v "$__out" '%s' "$result"
}

output=""
if (( ${#line1_parts[@]} > 0 )); then
  join_parts line1 "${line1_parts[@]}"
  output+="$line1"
fi
if (( ${#line2_parts[@]} > 0 )); then
  [[ -n "$output" ]] && output+=$'\n'
  join_parts line2 "${line2_parts[@]}"
  output+="$line2"
fi

echo -e "$output"
