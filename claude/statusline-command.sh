#!/usr/bin/env bash
# Claude Code status line
# Layout:
#   LEFT:  dir | model | progress | cost
#   RIGHT: runtime | branch [PR][CI] | dirty | session-elapsed | clock

input=$(cat)

# ── ANSI helpers ─────────────────────────────────────────────────────────────
RESET='\033[0m'
DIM='\033[2m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'

SEP_RAW=" | "
SEP="${DIM}${SEP_RAW}${RESET}"

strip_ansi() {
    printf '%s' "$1" | sed $'s/\033\\[[0-9;]*m//g'
}

visible_width() {
    # Counts visible characters (after stripping ANSI). Assumes single-width glyphs.
    strip_ansi "$1" | awk '{ printf "%d", length($0) }'
}

# ── Inputs ───────────────────────────────────────────────────────────────────
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir_name=""
[[ -n "$cwd" ]] && dir_name=$(basename "$cwd")

model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')

# ── Git: branch + dirty + PR ─────────────────────────────────────────────────
branch=""
pr_num=""
pr_info=""
dirty=""
if [[ -n "$cwd" ]]; then
    branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
    if [[ -n "$branch" ]]; then
        # Dirty: any uncommitted change (staged, unstaged, or untracked)
        if [[ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null | head -1)" ]]; then
            dirty="●"
        fi
        if command -v gh &>/dev/null; then
            pr_num=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null)
            if [[ -n "$pr_num" && "$pr_num" != "null" ]]; then
                pr_info=" #${pr_num}"
            else
                pr_num=""
            fi
        fi
    fi
fi

# ── Context window ───────────────────────────────────────────────────────────
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
# Window occupancy = input + cache_read + cache_creation from the last API call.
# (output_tokens are not in-window until the next turn folds them into input.)
cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cur_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
cur_cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
used_tokens=$(( cur_input + cur_cache_read + cur_cache_create ))

# Session-cumulative totals (input + output across the whole session).
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')

bar=""
bar_width=10
if [[ -n "$used_pct" ]]; then
    filled=$(echo "$used_pct $bar_width" | awk '{printf "%d", ($1/100)*$2 + 0.5}')
    empty=$(( bar_width - filled ))
    for (( i=0; i<filled; i++ )); do bar="${bar}█"; done
    for (( i=0; i<empty;  i++ )); do bar="${bar}░"; done
fi

pct_str=""
[[ -n "$used_pct" ]] && pct_str=$(printf "%.0f%%" "$used_pct")

token_str=""
if (( used_tokens > 0 )) && [[ -n "$ctx_size" ]]; then
    used_k=$(echo "$used_tokens" | awk '{if($1>=1000) printf "%.1fk", $1/1000; else printf "%d", $1}')
    total_k=$(echo "$ctx_size"   | awk '{if($1>=1000) printf "%.0fk", $1/1000; else printf "%d", $1}')
    token_str="${used_k}/${total_k}"
fi

session_tokens_str=""
if [[ -n "$total_in" && -n "$total_out" ]]; then
    sum=$(( total_in + total_out ))
    if (( sum > 0 )); then
        session_tokens_str=$(echo "$sum" | awk '{
            if ($1>=1000000) printf "Σ%.1fM", $1/1000000;
            else if ($1>=1000) printf "Σ%.0fk", $1/1000;
            else printf "Σ%d", $1
        }')
    fi
fi

# ── Cost ─────────────────────────────────────────────────────────────────────
cost_str=""
cost_raw=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
[[ -n "$cost_raw" ]] && cost_str=$(printf '$%.2f' "$cost_raw")

# ── Runtime / environment version ────────────────────────────────────────────
runtime_str=""
if [[ -n "$cwd" ]]; then
    if [[ -f "${cwd}/package.json" ]]; then
        if [[ -f "${cwd}/bun.lockb" || -f "${cwd}/bun.lock" ]]; then
            bun_ver=$(bun -v 2>/dev/null | head -1)
            [[ -n "$bun_ver" ]] && runtime_str="bun ${bun_ver}"
        fi
        if [[ -z "$runtime_str" ]] && command -v node &>/dev/null; then
            node_ver=$(node -v 2>/dev/null | head -1)
            [[ -n "$node_ver" ]] && runtime_str="node ${node_ver}"
        fi
    elif [[ -f "${cwd}/pyproject.toml" || -f "${cwd}/requirements.txt" ]]; then
        py_ver=$(python3 --version 2>/dev/null | awk '{print $2}')
        [[ -n "$py_ver" ]] && runtime_str="py ${py_ver}"
    elif [[ -f "${cwd}/Cargo.toml" ]]; then
        rust_ver=$(rustc --version 2>/dev/null | awk '{print $2}')
        [[ -n "$rust_ver" ]] && runtime_str="rust ${rust_ver}"
    elif [[ -f "${cwd}/go.mod" ]]; then
        go_ver=$(go version 2>/dev/null | awk '{print $3}' | sed 's/go//')
        [[ -n "$go_ver" ]] && runtime_str="go ${go_ver}"
    fi
fi

# ── Session elapsed (from cost.total_duration_ms) ────────────────────────────
session_str=""
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // empty')
if [[ -n "$duration_ms" && "$duration_ms" != "null" ]]; then
    sec=$(( duration_ms / 1000 ))
    h=$(( sec / 3600 ))
    m=$(( (sec % 3600) / 60 ))
    s=$(( sec % 60 ))
    if (( h > 0 )); then
        session_str=$(printf '%dh%02dm' "$h" "$m")
    elif (( m > 0 )); then
        session_str=$(printf '%dm%02ds' "$m" "$s")
    else
        session_str=$(printf '%ds' "$s")
    fi
fi

# ── Wall-clock time ──────────────────────────────────────────────────────────
clock_str=$(date +%H:%M)

# ── CI / PR check status ─────────────────────────────────────────────────────
ci_str=""
ci_raw=""
if [[ -n "$pr_num" ]] && command -v gh &>/dev/null; then
    checks_json=$(timeout 5 gh pr checks "$pr_num" --json name,state 2>/dev/null) || checks_json=""
    if [[ -n "$checks_json" ]]; then
        failing=$(echo "$checks_json" | jq '[.[] | select(.state=="FAILURE" or .state=="ERROR")] | length' 2>/dev/null)
        pending=$(echo "$checks_json" | jq '[.[] | select(.state=="PENDING" or .state=="IN_PROGRESS" or .state=="QUEUED")] | length' 2>/dev/null)
        total=$(echo "$checks_json"   | jq 'length' 2>/dev/null)
        if [[ -n "$total" && "$total" -gt 0 ]]; then
            if [[ "$failing" -gt 0 ]]; then
                ci_str=" ${RED}✗${failing}${RESET}"
                ci_raw=" ✗${failing}"
            elif [[ "$pending" -gt 0 ]]; then
                ci_str=" ⏳"
                ci_raw=" ⏳"
            else
                ci_str=" ${GREEN}✓${RESET}"
                ci_raw=" ✓"
            fi
        fi
    fi
fi

# ── Build segments ───────────────────────────────────────────────────────────
# Each "seg" pair: rendered (with ANSI), raw (for width). Empty segments dropped.

LEFT_RENDERED=()
LEFT_RAW=()
RIGHT_RENDERED=()
RIGHT_RAW=()

push() {
    local -n rendered_arr=$1
    local -n raw_arr=$2
    local rendered=$3
    local raw=$4
    [[ -z "$raw" ]] && return
    rendered_arr+=("$rendered")
    raw_arr+=("$raw")
}

# LEFT
[[ -n "$dir_name" ]] && push LEFT_RENDERED LEFT_RAW "${CYAN}${dir_name}${RESET}" "$dir_name"

push LEFT_RENDERED LEFT_RAW "${DIM}${model}${RESET}" "$model"

if [[ -n "$bar" ]]; then
    prog_rendered="[${bar}] ${DIM}${pct_str} ${token_str}${RESET}"
    prog_raw="[${bar}] ${pct_str} ${token_str}"
    push LEFT_RENDERED LEFT_RAW "$prog_rendered" "$prog_raw"
fi

[[ -n "$cost_str" ]] && push LEFT_RENDERED LEFT_RAW "${DIM}${cost_str}${RESET}" "$cost_str"

[[ -n "$session_tokens_str" ]] && push LEFT_RENDERED LEFT_RAW "${DIM}${session_tokens_str}${RESET}" "$session_tokens_str"

# RIGHT
[[ -n "$runtime_str" ]] && push RIGHT_RENDERED RIGHT_RAW "${DIM}${runtime_str}${RESET}" "$runtime_str"

if [[ -n "$branch" ]]; then
    git_seg_rendered=" ${branch}${DIM}${pr_info}${RESET}${ci_str}"
    git_seg_raw=" ${branch}${pr_info}${ci_raw}"
    push RIGHT_RENDERED RIGHT_RAW "$git_seg_rendered" "$git_seg_raw"
fi

[[ -n "$dirty" ]] && push RIGHT_RENDERED RIGHT_RAW "${YELLOW}${dirty}${RESET}" "$dirty"

[[ -n "$session_str" ]] && push RIGHT_RENDERED RIGHT_RAW "${DIM}${session_str}${RESET}" "$session_str"

push RIGHT_RENDERED RIGHT_RAW "${DIM}${clock_str}${RESET}" "$clock_str"

# Join with separators
join_segs() {
    local -n rendered_arr=$1
    local -n raw_arr=$2
    local mode=$3   # "rendered" or "raw"
    local out=""
    local i
    for i in "${!rendered_arr[@]}"; do
        local piece
        if [[ "$mode" == "rendered" ]]; then
            piece="${rendered_arr[$i]}"
        else
            piece="${raw_arr[$i]}"
        fi
        if [[ -z "$out" ]]; then
            out="$piece"
        else
            if [[ "$mode" == "rendered" ]]; then
                out="${out}${SEP}${piece}"
            else
                out="${out}${SEP_RAW}${piece}"
            fi
        fi
    done
    printf '%s' "$out"
}

left_rendered=$(join_segs LEFT_RENDERED LEFT_RAW rendered)
left_raw=$(join_segs LEFT_RENDERED LEFT_RAW raw)
right_rendered=$(join_segs RIGHT_RENDERED RIGHT_RAW rendered)
right_raw=$(join_segs RIGHT_RENDERED RIGHT_RAW raw)

# ── Right-align ──────────────────────────────────────────────────────────────
# Try to determine terminal width; fall back to 120
cols="${COLUMNS:-}"
if [[ -z "$cols" ]]; then
    cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
fi
[[ -z "$cols" ]] && cols=$(tput cols 2>/dev/null)
[[ -z "$cols" || "$cols" -lt 40 ]] && cols=120

left_w=$(visible_width "$left_raw")
right_w=$(visible_width "$right_raw")
gap=$(( cols - left_w - right_w ))
(( gap < 1 )) && gap=1

pad=$(printf '%*s' "$gap" '')

printf '%b%s%b' "$left_rendered" "$pad" "$right_rendered"
