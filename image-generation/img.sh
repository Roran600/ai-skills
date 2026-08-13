#!/usr/bin/env bash
set -euo pipefail

# Minimal bash toolkit for OpenRouter MCP image generation.

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
DEFAULT_MCP_URL="https://mcp.openrouter.ai/mcp"
DEFAULT_AUTH_PATH="${HOME}/.local/share/opencode/mcp-auth.json"

err() { printf "[err] %s\n" "$*" >&2; }
die() { err "$*"; exit 1; }

help() {
  cat <<'EOF'
Usage: img.sh <command> [args]

Commands:
  mcp <tool> <json>      Call an MCP tool with JSON args
  models                 List live image models (cheap -> expensive)
  size <ratio> <tier>    Compute size string; ratio 1:1/16:9/9:16/4:3/3:4/21:9, tier 1K|2K|4K
  gen [opts] prompts..   Generate images (one MCP call per prompt)
  extract <file|-> [outdir] [base]  Decode base64 image(s) from payload
  upscale <in> <2|4> [out]          Resize with ImageMagick Lanczos

Auth resolution (in order):
  1) $OPENROUTER_API_KEY
  2) $OPENCODE_MCP_AUTH (path) else ~/.local/share/opencode/mcp-auth.json

Examples:
  ./img.sh size 16:9 2K
  ./img.sh models | head
  ./img.sh gen -m black-forest-labs/flux.2-pro -r 16:9 -q 2K -o out "sunset city" "mountain lake"
  cat response.json | ./img.sh extract - out img
EOF
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
require_cmd curl; require_cmd jq; require_cmd base64; require_cmd awk

auth_token() {
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    echo "$OPENROUTER_API_KEY"; return 0
  fi
  local auth_path="${OPENCODE_MCP_AUTH:-$DEFAULT_AUTH_PATH}"
  [[ -f "$auth_path" ]] || die "Auth file not found: $auth_path (or set OPENROUTER_API_KEY)"
  local token expires
  token=$(jq -r '.openrouter.tokens.accessToken // empty' "$auth_path")
  expires=$(jq -r '.openrouter.tokens.expiresAt // 0' "$auth_path")
  [[ -n "$token" ]] || die "No accessToken in $auth_path; re-run OpenRouter MCP login"
  local now
  now=$(date +%s)
  if [[ "$expires" != "" && "$expires" != "null" ]]; then
    local exp_int=${expires%.*}
    if (( now >= exp_int )); then
      die "MCP token expired; open OpenCode and hit any openrouter MCP tool to refresh"
    fi
  fi
  echo "$token"
}

mcp_url() {
  local auth_path="${OPENCODE_MCP_AUTH:-$DEFAULT_AUTH_PATH}"
  if [[ -f "$auth_path" ]]; then
    local url
    url=$(jq -r '.openrouter.serverUrl // empty' "$auth_path")
    [[ -n "$url" && "$url" != "null" ]] && { echo "$url"; return; }
  fi
  echo "$DEFAULT_MCP_URL"
}

mcp_call() {
  local tool=$1; shift || true
  local args_json=${1:-"{}"}
  local args
  args=$(printf '%s' "$args_json" | jq -c . 2>/dev/null) || die "Invalid JSON args"
  local body
  body=$(jq -nc --arg name "$tool" --argjson args "$args" '{jsonrpc:"2.0",id:1,method:"tools/call",params:{name:$name,arguments:$args}}')
  local token url
  token=$(auth_token)
  url=$(mcp_url)
  local res
  res=$(curl -sS -X POST "$url" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H 'MCP-Protocol-Version: 2025-11-25' \
    -H "Authorization: Bearer $token" \
    -d "$body")
  # If SSE, pull JSON lines; else pass through
  if printf '%s' "$res" | grep -q '^data:'; then
    res=$(printf '%s\n' "$res" | sed -n 's/^data: //p' | grep -v '^\[DONE\]')
  fi
  printf '%s\n' "$res"
}

cmd_models() {
  local payload='{"request":{"output_modalities":"image","limit":30,"sort":"pricing-low-to-high"}}'
  mcp_call list-models "$payload" | jq -r '.result.data[] | [.id, (.pricing.prompt // .pricing.output // null), (.architecture.output_modalities|tostring)] | @tsv' 2>/dev/null || true
}

cmd_size() {
  local ratio=${1:-}; local tier=${2:-}
  [[ -n "$ratio" && -n "$tier" ]] || die "Usage: size <ratio> <tier>"
  case "$tier" in 1K|1k|standard) base=1024;; 2K|2k|high) base=2048;; 4K|4k|ultra) base=4096;; *) die "Tier must be 1K|2K|4K";; esac
  if [[ "$ratio" == "1:1" ]]; then
    case "$base" in 1024) echo "1K";; 2048) echo "2K";; 4096) echo "4K";; esac
    return
  fi
  local dims
  dims=$(awk -v r="$ratio" -v b="$base" 'BEGIN{split(r,a,":"); s=a[1]/a[2]; w=int(b*sqrt(s)/8+0.5)*8; h=int(b/sqrt(s)/8+0.5)*8; printf "%d %d",w,h}') || die "Failed to compute size"
  local w h
  read -r w h <<<"$dims"
  printf "%dx%d\n" "$w" "$h"
}

safe_slug() { echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-\+//;s/-\+$//' ; }

cmd_extract() {
  local src=${1:-}; local outdir=${2:-./out}; local base=${3:-img}
  [[ -n "$src" ]] || die "Usage: extract <file|-> [outdir] [base]"
  mkdir -p "$outdir"
  local payload
  if [[ "$src" == "-" ]]; then
    payload=$(cat)
  else
    payload=$(cat "$src")
  fi
  local b64s
  b64s=$(printf '%s' "$payload" | jq -r '
    (.. | objects | select(.type?=="image") | .data?),
    (.. | objects | .b64_json?),
    (.. | strings | select(test("^data:image/[^;]+;base64,")) | sub("^data:image/[^;]+;base64,",""))
  ' 2>/dev/null | grep -v '^null$' || true)
  if [[ -z "$b64s" ]]; then
    die "No image base64 found"
  fi
  local idx=1
  while IFS= read -r b64; do
    [[ -z "$b64" ]] && continue
    local tmp=$(mktemp)
    printf '%s' "$b64" | base64 -d > "$tmp" || { rm -f "$tmp"; die "base64 decode failed"; }
    local mime ext
    mime=$(file --mime-type -b "$tmp" 2>/dev/null || echo "application/octet-stream")
    case "$mime" in
      image/png) ext=png;; image/jpeg) ext=jpg;; image/webp) ext=webp;; image/svg+xml) ext=svg;; *) ext=bin;; esac
    local name=$(printf "%s/%s-%02d.%s" "$outdir" "$base" "$idx" "$ext")
    mv "$tmp" "$name"
    printf "%s\n" "$name"
    idx=$((idx+1))
  done <<<"$b64s"
}

cmd_gen() {
  local model="" ratio="1:1" tier="1K" outdir="./out" prompt_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--model) model=$2; shift 2;;
      -r|--ratio) ratio=$2; shift 2;;
      -q|--tier) tier=$2; shift 2;;
      -o|--out) outdir=$2; shift 2;;
      -f|--file) prompt_file=$2; shift 2;;
      --) shift; break;;
      -h|--help) help; exit 0;;
      *) break;;
    esac
  done
  [[ -n "$model" ]] || die "-m|--model is required"
  mkdir -p "$outdir"
  local size
  size=$(cmd_size "$ratio" "$tier")
  local prompts=()
  if [[ -n "$prompt_file" ]]; then
    while IFS= read -r line; do [[ -n "$line" ]] && prompts+=("$line"); done < "$prompt_file"
  fi
  if [[ $# -gt 0 ]]; then prompts+=("$@"); fi
  [[ ${#prompts[@]} -gt 0 ]] || die "No prompts supplied"
  printf "Generating %d image(s) on %s size=%s -> %s\n" "${#prompts[@]}" "$model" "$size" "$outdir"
  local i=1
  for p in "${prompts[@]}"; do
    local args
    args=$(jq -nc --arg m "$model" --arg pr "$p" --arg sz "$size" '{model:$m,prompt:$pr,size:$sz}')
    local res
    res=$(mcp_call generate-image "$args")
    local base=$(printf "%02d-%s" "$i" "$(safe_slug "$model")")
    printf '%s\n' "$res" | cmd_extract - "$outdir" "$base"
    # sidecar
    jq -nc --arg model "$model" --arg prompt "$p" --arg size "$size" --arg time "$(date -Iseconds)" '{model:$model,prompt:$prompt,size:$size,created:$time}' > "$outdir/$base.json"
    i=$((i+1))
  done
}

cmd_upscale() {
  require_cmd magick
  local src=${1:-}; local factor=${2:-}; local dst=${3:-}
  [[ -n "$src" && -n "$factor" ]] || die "Usage: upscale <in> <2|4> [out]"
  case "$factor" in 2|4) ;; *) die "factor must be 2 or 4";; esac
  [[ -f "$src" ]] || die "Input not found: $src"
  local out=${dst:-${src%.*}-x${factor}.${src##*.}}
  magick "$src" -filter Lanczos -resize "${factor}00%" -unsharp 0x0.75+0.75+0.008 "$out"
  printf "%s\n" "$out"
}

case "${1:-}" in
  mcp) shift; mcp_call "$@";;
  models) shift; cmd_models "$@";;
  size) shift; cmd_size "$@";;
  gen) shift; cmd_gen "$@";;
  extract) shift; cmd_extract "$@";;
  upscale) shift; cmd_upscale "$@";;
  -h|--help|help|"") help;;
  *) die "Unknown command: $1";;
esac
