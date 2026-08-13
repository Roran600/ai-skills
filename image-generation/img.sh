#!/usr/bin/env bash
set -euo pipefail

# Minimal bash toolkit for OpenRouter MCP image generation.
#
# stdout contract:
#   gen / extract / upscale  -> produced file paths only (one per line)
#   menu (dry-run)           -> the resolved plan
#   everything else (UI, diagnostics, prompts) -> stderr

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
# Absolute path to this script. Every command the script suggests must be
# runnable from any cwd: an agent's working directory is never SCRIPT_DIR,
# so a relative "./img.sh" hint is a dead end.
SELF="$SCRIPT_DIR/${0##*/}"
DEFAULT_MCP_URL="https://mcp.openrouter.ai/mcp"
DEFAULT_AUTH_PATH="${HOME}/.local/share/opencode/mcp-auth.json"

EX_NO_TTY=2
EX_PENDING_REFS=10

RATIO_LIST=(1:1 16:9 9:16 4:3 3:4 21:9)
TIER_LIST=(1K 2K 4K)

err()  { printf "[err] %s\n" "$*" >&2; }
info() { printf "%s\n" "$*" >&2; }
ui()   { printf "%s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

help() {
  cat >&2 <<'EOF'
Usage: img.sh <command> [args]

Commands:
  menu [opts]            Interactive picker (model, refs, ratio, resolution, upscale)
  mcp <tool|method> <json>  Call an MCP tool, or a bare JSON-RPC method (tools/list)
  models [cat] [N]       List image models; cat = price|speed|quality (default: legacy price list)
  size <ratio> <tier>    Compute size string; ratio 1:1/16:9/9:16/4:3/3:4/21:9, tier 1K|2K|4K
  gen [opts] prompts..   Generate images (one paid MCP call per prompt)
  extract <file|-> [outdir] [base]  Decode base64 image(s) from a payload
  upscale <in> <2|4> [out]          Resample with ImageMagick Lanczos
  reffacts <image>       Print objective facts (palette, aspect, tone) as JSON

gen options:
  -m MODEL  -r RATIO  -q TIER  -o OUTDIR  -f PROMPTFILE
  --upscale 2|4        Also upscale every produced image
  --refs-json JSON     Reference metadata to embed in the sidecar

menu options (non-interactive contract for agents):
  --non-interactive    Required when there is no TTY
  --questions          Print the questionnaire to ask the user, then exit (no TTY needed)
  --yes                Actually spend money (without it: dry-run)
  --dry-run            Print the resolved plan and exit
  --max-calls N        Circuit breaker, default 4
  -m/--model, -r/--ratio, -q/--tier, -o/--out
  --prompt TEXT        Repeatable
  --ref PATH           Repeatable
  --ref-desc TEXT      Repeatable, pairs with --ref by order
  --no-palette         Omit hex palette from the reference brief
  --upscale 2|4

Output directory:
  Interactive `menu` asks where to save first thing: current directory (default),
  a custom path, or ./out. Passing -o/--out skips that question. Non-interactive
  runs never ask and fall back to ./out.

menu exit codes:
  0   ok / dry-run
  2   no TTY and --non-interactive not given
  10  --ref given without --ref-desc; refs.pending.json written, nothing spent

Auth resolution (in order):
  1) $OPENROUTER_API_KEY
  2) $OPENCODE_MCP_AUTH (path) else ~/.local/share/opencode/mcp-auth.json
EOF
  # Second heredoc is unquoted so the examples carry the real absolute path.
  # An agent's cwd is never this directory, so "./img.sh" would not run.
  cat >&2 <<EOF

Examples (copy-pasteable from any directory):
  $SELF menu
  $SELF size 16:9 2K
  $SELF models | head
  $SELF gen -m black-forest-labs/flux.2-pro -r 16:9 -q 2K -o . "sunset city"
  $SELF menu --non-interactive --yes -m qwen/qwen-image-3 -o . --prompt "a cat"
EOF
}

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
require_cmd curl; require_cmd jq; require_cmd base64; require_cmd awk

# ---------------------------------------------------------------- auth / MCP

auth_token() {
  if [[ -n "${OPENROUTER_API_KEY:-}" ]]; then
    printf '%s' "$OPENROUTER_API_KEY"; return 0
  fi
  local auth_path="${OPENCODE_MCP_AUTH:-$DEFAULT_AUTH_PATH}"
  [[ -f "$auth_path" ]] || die "Auth file not found: $auth_path (or set OPENROUTER_API_KEY)"
  local token expires
  token=$(jq -r '.openrouter.tokens.accessToken // empty' "$auth_path")
  expires=$(jq -r '.openrouter.tokens.expiresAt // 0' "$auth_path")
  [[ -n "$token" ]] || die "No accessToken in $auth_path; re-run OpenRouter MCP login"
  local now exp_int
  now=$(date +%s)
  if [[ -n "$expires" && "$expires" != "null" ]]; then
    exp_int=${expires%.*}
    # expiresAt may be seconds or milliseconds
    (( ${#exp_int} > 12 )) && exp_int=$(( exp_int / 1000 ))
    if (( exp_int > 0 && now >= exp_int )); then
      die "MCP token expired; open OpenCode and hit any openrouter MCP tool to refresh"
    fi
  fi
  printf '%s' "$token"
}

mcp_url() {
  local auth_path="${OPENCODE_MCP_AUTH:-$DEFAULT_AUTH_PATH}"
  if [[ -f "$auth_path" ]]; then
    local url
    url=$(jq -r '.openrouter.serverUrl // empty' "$auth_path")
    [[ -n "$url" && "$url" != "null" ]] && { printf '%s' "$url"; return; }
  fi
  printf '%s' "$DEFAULT_MCP_URL"
}

mcp_rpc() {
  local method=$1; shift || true
  local params_json=${1:-"{}"}
  local params
  params=$(printf '%s' "$params_json" | jq -c . 2>/dev/null) || die "Invalid JSON params"
  local body token url res
  body=$(jq -nc --arg m "$method" --argjson p "$params" \
    '{jsonrpc:"2.0",id:1,method:$m,params:$p}')
  token=$(auth_token)
  url=$(mcp_url)
  res=$(curl -sS -X POST "$url" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -H 'MCP-Protocol-Version: 2025-11-25' \
    -H "Authorization: Bearer $token" \
    -d "$body")
  if printf '%s' "$res" | head -c 64 | grep -q '^data:'; then
    res=$(printf '%s\n' "$res" | sed -n 's/^data: //p' | grep -v '^\[DONE\]')
  fi
  printf '%s\n' "$res"
}

# Bare JSON-RPC methods are not tool calls.
mcp_call() {
  local tool=${1:-}; shift || true
  [[ -n "$tool" ]] || die "Usage: mcp <tool|method> [json]"
  case "$tool" in
    tools/list|resources/list|resources/templates/list|prompts/list|ping)
      mcp_rpc "$tool" "${1:-{\}}"; return;;
  esac
  local args_json=${1:-"{}"} args
  args=$(printf '%s' "$args_json" | jq -c . 2>/dev/null) || die "Invalid JSON args"
  mcp_rpc tools/call "$(jq -nc --arg name "$tool" --argjson args "$args" '{name:$name,arguments:$args}')"
}

# Unwraps the catalogue, which arrives as a JSON string inside a text content block.
# The API's pricing-low-to-high sorts by prompt price, which is $0/M for every image
# model, so the order it returns is meaningless. Sort by parsed image price instead.
#
# No argument  -> the legacy 2-column "id<TAB>price" list (agents rely on this,
#                 the output is deliberately kept byte-for-byte stable).
# An argument  -> ranked, multi-column table via model_table (price|speed|quality).
cmd_models() {
  if [[ -n "${1:-}" ]]; then model_table "$@"; return; fi
  local payload='{"request":{"output_modalities":"image","limit":40,"sort":"pricing-low-to-high"}}'
  mcp_call list-models "$payload" \
    | jq -r '[ ((.result.content[]? | select(.type=="text") | .text | fromjson | .data[]?),
                (.result.data[]?)) ]
             | map({ id:    .id,
                     price: (.pricing.image_output // .pricing.prompt // "-"),
                     n:     ((.pricing.image_output // .pricing.prompt // "") | tostring
                             | gsub("[^0-9.]"; "")
                             | if . == "" or . == "." then 1e9 else ((tonumber? // 1e9)) end) })
             | map(select(.id != null))
             | sort_by(.n)
             | .[] | [.id, .price] | @tsv' 2>/dev/null || true
}

# ---------------------------------------------------------------- ranking

# All three rankings come from the OpenRouter MCP, never REST/SDK. Each source
# is a JSON array unwrapped from the text content block, cached once per session.
CAT_RAW=""; THR_RAW=""; ARENA_RAW=""

# mcp_data <tool> <payload> -> compact JSON array (the .data payload)
mcp_data() {
  mcp_call "$1" "$2" \
    | jq -c '[.result.content[]? | select(.type=="text") | .text | fromjson | .data] | add // []' \
      2>/dev/null || printf '[]'
}

cat_raw()   { [[ -n "$CAT_RAW" ]]   || CAT_RAW=$(mcp_data list-models     '{"request":{"output_modalities":"image","limit":100}}'); printf '%s' "$CAT_RAW"; }
thr_raw()   { [[ -n "$THR_RAW" ]]   || THR_RAW=$(mcp_data list-models     '{"request":{"output_modalities":"image","limit":100,"sort":"throughput-high-to-low"}}'); printf '%s' "$THR_RAW"; }
arena_raw() { [[ -n "$ARENA_RAW" ]] || ARENA_RAW=$(mcp_data list-benchmarks '{"request":{"source":"design-arena","category":"image"}}'); printf '%s' "$ARENA_RAW"; }

# model_table <price|speed|quality> [N]  -> TSV, slug ALWAYS the first column
#   columns: id  price_disp  elo  win%  speed
# price   : cheapest image price first (data for ~43/45 models)
# quality : highest design-arena elo first, measured models only (~10)
# speed   : measured avg generation time first, then throughput proxy (~rN)
# API latency sort is NOT used: it ranks a 201s model as 11th-fastest of 45
# because it measures time-to-first-token, not image time.
model_table() {
  local cat=${1:-price} n=${2:-20}
  case "$cat" in price|speed|quality) ;; *) die "category must be price|speed|quality";; esac
  [[ "$n" =~ ^[0-9]+$ ]] || die "N must be a number"
  local catd thrd arend
  catd=$(cat_raw); thrd=$(thr_raw)
  if [[ -z "$catd" || "$catd" == "[]" ]]; then
    err "NO MODEL DATA from MCP - use the default model black-forest-labs/flux.2-klein-4b"
    return 1
  fi
  arend='[]'
  if [[ "$cat" != "price" ]]; then
    arend=$(arena_raw)
    if [[ -z "$arend" || "$arend" == "[]" ]]; then
      err "NO RANKING DATA from MCP - use the default model black-forest-labs/flux.2-klein-4b"
      return 1
    fi
  fi
  jq -rn --argjson cat "$catd" --argjson thr "$thrd" --argjson arena "$arend" \
         --arg cat_key "$cat" --argjson n "$n" '
    ( [ $thr[] | .canonical_slug ] | to_entries
      | map({key:.value, value:(.key+1)}) | from_entries ) as $thrrank
    | ( $arena | group_by(.model_permaslug)
        | map({ key: .[0].model_permaslug,
                value: { elo: (map(.elo)|max),
                         win: (map(.win_rate)|max),
                         ms:  (map(.avg_generation_time_ms)|min) } })
        | from_entries ) as $ar
    | [ $cat[]
        | . as $m
        | ($m.pricing.image_output // $m.pricing.image_token // $m.pricing.prompt // "") as $pr
        | ($pr | tostring | gsub("[^0-9.]";"")
           | if . == "" or . == "." then null else (tonumber? // null) end) as $pnum
        | ($ar[$m.canonical_slug]) as $a
        | { id: $m.id,
            pnum: ($pnum // 1e18),
            pdisp: (if $pr == "" then "-" else ($pr|tostring) end),
            elo: ($a.elo), win: ($a.win), ms: ($a.ms),
            thr: ($thrrank[$m.canonical_slug] // 999) } ]
    | ( if   $cat_key == "price"   then [ .[] | select(.pnum < 1e18) ] | sort_by(.pnum)
        elif $cat_key == "quality" then [ .[] | select(.elo != null) ] | sort_by(-.elo)
        elif $cat_key == "speed"   then
             ( [ .[] | select(.ms != null) ] | sort_by(.ms) )
           + ( [ .[] | select(.ms == null) ] | sort_by(.thr) )
        else . end )
    | .[0:$n] | .[]
    | [ .id, .pdisp,
        (if .elo == null then "-" else (.elo|floor|tostring) end),
        (if .win == null then "-" else ((.win|floor|tostring) + "%") end),
        (if .ms != null then ((.ms/1000|floor|tostring) + "s")
         elif .thr != 999 then ("~r" + (.thr|tostring))
         else "-" end) ]
    | @tsv'
}

# ---------------------------------------------------------------- size

cmd_size() {
  local ratio=${1:-} tier=${2:-} base
  [[ -n "$ratio" && -n "$tier" ]] || die "Usage: size <ratio> <tier>"
  case "$tier" in
    1K|1k|standard) base=1024;;
    2K|2k|high)     base=2048;;
    4K|4k|ultra)    base=4096;;
    *) die "Tier must be 1K|2K|4K";;
  esac
  if [[ "$ratio" == "1:1" ]]; then
    case "$base" in 1024) echo "1K";; 2048) echo "2K";; 4096) echo "4K";; esac
    return
  fi
  [[ "$ratio" == *:* ]] || die "Ratio must look like 16:9"
  local dims w h
  dims=$(awk -v r="$ratio" -v b="$base" 'BEGIN{
      split(r,a,":");
      if (a[1]+0 <= 0 || a[2]+0 <= 0) exit 1;
      s=a[1]/a[2];
      w=int(b*sqrt(s)/8+0.5)*8; h=int(b/sqrt(s)/8+0.5)*8;
      printf "%d %d",w,h
    }') || die "Failed to compute size for ratio $ratio"
  read -r w h <<<"$dims"
  printf "%dx%d\n" "$w" "$h"
}

safe_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._-' '-' | sed 's/^-\+//;s/-\+$//'
}

# ---------------------------------------------------------------- extract

# Surfaces the real MCP error instead of a misleading "no image found".
payload_error_text() {
  jq -r '
    if (.error? != null) or (.result?.isError? == true) then
      [ (.error?.message? // empty),
        (.result?.content[]? | select(.type=="text") | .text) ] | join(" | ")
    else empty end' 2>/dev/null || true
}

cmd_extract() {
  local src=${1:-} outdir=${2:-./out} base=${3:-img}
  [[ -n "$src" ]] || die "Usage: extract <file|-> [outdir] [base]"
  mkdir -p "$outdir"
  local payload
  if [[ "$src" == "-" ]]; then payload=$(cat); else
    [[ -f "$src" ]] || die "Payload not found: $src"
    payload=$(cat "$src")
  fi
  [[ -n "$payload" ]] || die "Empty payload"

  local errtext
  errtext=$(printf '%s' "$payload" | payload_error_text)
  [[ -z "$errtext" ]] || die "MCP returned an error: $errtext"

  # Order-preserving dedupe: sorting would scramble multi-image order.
  local b64s
  b64s=$(printf '%s' "$payload" | jq -r '
    [ (.. | objects | select(.type? == "image") | .data? // empty),
      (.. | objects | .b64_json? // empty),
      (.. | strings
          | select(startswith("data:image/"))
          | sub("^data:image/[^;]+;base64,"; "")) ]
    | map(select(type == "string" and length > 0))
    | reduce .[] as $x ([]; if index($x) then . else . + [$x] end)
    | .[]' 2>/dev/null || true)

  local -a b64arr=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && b64arr+=("$line")
  done <<<"$b64s"

  local n=${#b64arr[@]}
  (( n > 0 )) || die "No image base64 found in response"

  local idx=1 b64 tmp mime ext name
  for b64 in "${b64arr[@]}"; do
    tmp=$(mktemp) || die "mktemp failed"
    if ! printf '%s' "$b64" | base64 -d > "$tmp" 2>/dev/null; then
      rm -f "$tmp"; die "base64 decode failed for image #$idx"
    fi
    mime=$(file --mime-type -b "$tmp" 2>/dev/null || echo "application/octet-stream")
    case "$mime" in
      image/png)     ext=png;;
      image/jpeg)    ext=jpg;;
      image/webp)    ext=webp;;
      image/gif)     ext=gif;;
      image/svg+xml) ext=svg;;
      *) ext=bin; err "unexpected mime $mime for image #$idx";;
    esac
    if (( n == 1 )); then
      name="$outdir/$base.$ext"
    else
      name=$(printf "%s/%s-%02d.%s" "$outdir" "$base" "$idx" "$ext")
    fi
    mv "$tmp" "$name"
    printf '%s\n' "$name"
    idx=$((idx+1))
  done
}

# Keeps cost/model/tokens, drops the multi-MB base64.
raw_scrub() {
  local raw=$1 tmp
  tmp=$(mktemp) || return 1
  if jq 'walk(
          if type == "object" then
            with_entries(
              if (.key == "data" or .key == "b64_json")
                 and (.value | type) == "string"
                 and (.value | length) > 512
              then .value = "<base64 stripped: \(.value | length) chars>"
              else . end)
          else . end)' "$raw" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
    mv "$tmp" "$raw"
  else
    rm -f "$tmp"
  fi
}

# ---------------------------------------------------------------- generate

cmd_gen() {
  local model="" ratio="1:1" tier="1K" outdir="./out" prompt_file="" upscale="" refs_json=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -m|--model) model=${2:-}; shift 2;;
      -r|--ratio) ratio=${2:-}; shift 2;;
      -q|--tier)  tier=${2:-}; shift 2;;
      -o|--out)   outdir=${2:-}; shift 2;;
      -f|--file)  prompt_file=${2:-}; shift 2;;
      --upscale)  upscale=${2:-}; shift 2;;
      --refs-json) refs_json=${2:-}; shift 2;;
      --) shift; break;;
      -h|--help) help; exit 0;;
      -*) die "Unknown gen option: $1";;
      *) break;;
    esac
  done
  [[ -n "$model" ]] || die "-m|--model is required"
  [[ -z "$upscale" || "$upscale" == "2" || "$upscale" == "4" ]] || die "--upscale must be 2 or 4"
  mkdir -p "$outdir"

  local size
  size=$(cmd_size "$ratio" "$tier")

  local -a prompts=()
  if [[ -n "$prompt_file" ]]; then
    [[ -f "$prompt_file" ]] || die "Prompt file not found: $prompt_file"
    # `|| [[ -n $line ]]` keeps the last line when the file has no trailing newline.
    while IFS= read -r line || [[ -n "$line" ]]; do
      [[ -n "$line" ]] && prompts+=("$line")
    done < "$prompt_file"
  fi
  (( $# > 0 )) && prompts+=("$@")
  (( ${#prompts[@]} > 0 )) || die "No prompts supplied"

  info "Generating ${#prompts[@]} image(s) on $model size=$size -> $outdir"

  # Raws live in a subdir so that "$outdir"/*.json matches sidecars only.
  local rawdir="$outdir/raw"
  mkdir -p "$rawdir"

  local i=1 failed=0 total_cost=0
  local p args base raw sidecar cost tokens txt files_json up
  local -a produced=()
  for p in "${prompts[@]}"; do
    base=$(printf "%02d-%s" "$i" "$(safe_slug "$model")")
    raw="$rawdir/$base.raw.json"
    sidecar="$outdir/$base.json"
    args=$(jq -nc --arg m "$model" --arg pr "$p" --arg sz "$size" \
      '{model:$m,prompt:$pr,size:$sz}')

    # Raw lands on disk before any parsing, so a paid image is never lost.
    if ! mcp_call generate-image "$args" > "$raw" 2>/dev/null; then
      err "prompt #$i: MCP call failed (raw: $raw)"
      failed=$((failed+1)); i=$((i+1)); continue
    fi

    txt=$(jq -r '[.result?.content[]? | select(.type=="text") | .text] | join(" ")' "$raw" 2>/dev/null || true)
    cost=""; tokens=""
    [[ $txt =~ cost:\ *\$?([0-9.]+) ]] && cost="${BASH_REMATCH[1]}"
    [[ $txt =~ tokens:\ *([0-9]+) ]] && tokens="${BASH_REMATCH[1]}"

    # Sidecar is written before extraction, so there is always a record of what was paid for.
    jq -nc \
      --arg model "$model" --arg prompt "$p" --arg size "$size" \
      --arg time "$(date -Iseconds)" --arg cost "$cost" --arg tokens "$tokens" \
      --arg raw "$raw" --arg refs "$refs_json" \
      '{model:$model, prompt:$prompt, size:$size, created:$time,
        cost:(if $cost=="" then null else ($cost|tonumber) end),
        tokens:(if $tokens=="" then null else ($tokens|tonumber) end),
        raw:$raw, status:"pending"}
       + (if $refs=="" then {} else {refs:($refs|fromjson)} end)' > "$sidecar"

    [[ -n "$cost" ]] && total_cost=$(awk -v a="$total_cost" -v b="$cost" 'BEGIN{printf "%.6f", a+b}')

    # `if !` keeps set -e from aborting the whole batch on one bad response.
    local out_files=""
    if ! out_files=$(cmd_extract "$raw" "$outdir" "$base"); then
      err "prompt #$i: extraction failed; full raw kept at $raw"
      jq '.status="failed"' "$sidecar" > "$sidecar.tmp" && mv "$sidecar.tmp" "$sidecar"
      failed=$((failed+1)); i=$((i+1)); continue
    fi

    local -a these=()
    while IFS= read -r f; do [[ -n "$f" ]] && these+=("$f"); done <<<"$out_files"

    local -a ups=()
    if [[ -n "$upscale" ]]; then
      for f in "${these[@]}"; do
        if u=$(cmd_upscale "$f" "$upscale" 2>/dev/null); then ups+=("$u"); else err "upscale failed: $f"; fi
      done
    fi

    files_json=$(printf '%s\n' "${these[@]}" | jq -R . | jq -sc .)
    local upscaled_json='[]'
    (( ${#ups[@]} > 0 )) && upscaled_json=$(printf '%s\n' "${ups[@]}" | jq -R . | jq -sc .)
    jq --argjson files "$files_json" --argjson ups "$upscaled_json" \
       '.status="ok" | .files=$files | .upscaled=$ups' "$sidecar" > "$sidecar.tmp" \
       && mv "$sidecar.tmp" "$sidecar"

    raw_scrub "$raw"

    produced+=("${these[@]}")
    (( ${#ups[@]} > 0 )) && produced+=("${ups[@]}")
    i=$((i+1))
  done

  (( ${#produced[@]} > 0 )) && printf '%s\n' "${produced[@]}"

  local ok=$(( ${#prompts[@]} - failed ))
  # Unmistakable completion signal: without it the caller has to infer success
  # from stdout, and a cautious one reports "a plan" instead of a result.
  if (( ${#produced[@]} > 0 )); then
    info "IMAGE(S) CREATED:"
    printf '  %s\n' "${produced[@]}" >&2
  else
    err "NO IMAGE WAS CREATED."
  fi
  info "Done: $ok ok, $failed failed. Actual cost reported by MCP: \$$total_cost"
  (( failed == 0 )) || return 1
}

# ---------------------------------------------------------------- upscale

cmd_upscale() {
  require_cmd magick
  local src=${1:-} factor=${2:-} dst=${3:-}
  [[ -n "$src" && -n "$factor" ]] || die "Usage: upscale <in> <2|4> [out]"
  case "$factor" in 2|4) ;; *) die "factor must be 2 or 4";; esac
  [[ -f "$src" ]] || die "Input not found: $src"
  local out=$dst
  if [[ -z "$out" ]]; then
    local dir bn ext stem
    dir=$(dirname -- "$src"); bn=$(basename -- "$src")
    if [[ "$bn" == *.* ]]; then ext=${bn##*.}; stem=${bn%.*}; else ext=png; stem=$bn; fi
    out="$dir/$stem-x$factor.$ext"
  fi
  magick "$src" -filter Lanczos -resize "${factor}00%" -unsharp 0x0.75+0.75+0.008 "$out"
  printf '%s\n' "$out"
}

# ---------------------------------------------------------------- references

# MCP generate-image cannot accept images, so a reference has to become text.
# Only objectively measurable facts are derived here; subject/style needs words.
ref_facts() {
  require_cmd magick
  local f=${1:-}
  [[ -n "$f" ]] || die "Usage: reffacts <image>"
  [[ -f "$f" ]] || die "Reference not found: $f"
  local dims w h pal L S aspect orient
  dims=$(magick "$f" -format "%wx%h" info: 2>/dev/null) || die "Not a readable image: $f"
  w=${dims%x*}; h=${dims#*x}
  pal=$(magick "$f" -alpha off -resize 200x200! -colors 5 -unique-colors -depth 8 txt: 2>/dev/null \
        | awk 'NR>1 && $3 ~ /^#/ {printf "%s%s", (n++?" ":""), $3}')
  L=$(magick "$f" -colorspace HSL -format "%[fx:int(mean.b*100)]" info: 2>/dev/null || echo "")
  S=$(magick "$f" -colorspace HSL -format "%[fx:int(mean.g*100)]" info: 2>/dev/null || echo "")
  # Nearest of the six supported ratios.
  aspect=$(awk -v w="$w" -v h="$h" 'BEGIN{
      split("1:1 16:9 9:16 4:3 3:4 21:9", r, " ");
      target=w/h; best=""; bd=1e9;
      for (i=1; i<=6; i++) { split(r[i], a, ":"); v=a[1]/a[2]; d=(v>target?v-target:target-v);
        if (d<bd) { bd=d; best=r[i] } }
      print best }')
  if   (( w > h )); then orient=landscape
  elif (( h > w )); then orient=portrait
  else orient=square; fi
  jq -nc --arg path "$f" --arg dims "$dims" --arg aspect "$aspect" --arg orient "$orient" \
         --arg pal "$pal" --arg L "$L" --arg S "$S" \
    '{path:$path, dims:$dims, aspect:$aspect, orientation:$orient,
      palette:($pal | if .=="" then [] else split(" ") end),
      lightness:(if $L=="" then null else ($L|tonumber) end),
      saturation:(if $S=="" then null else ($S|tonumber) end),
      description:""}'
}

tone_words() {
  local L=${1:-} S=${2:-} out=""
  if [[ -n "$L" && "$L" != "null" ]]; then
    if   (( L < 35 )); then out="dark"
    elif (( L > 65 )); then out="bright"
    else out="mid-tone"; fi
  fi
  if [[ -n "$S" && "$S" != "null" ]]; then
    if   (( S < 25 )); then out="${out:+$out, }desaturated"
    elif (( S > 60 )); then out="${out:+$out, }highly saturated"
    else out="${out:+$out, }moderately saturated"; fi
  fi
  printf '%s' "$out"
}

# refs_json array -> one text block appended to the prompt
build_ref_brief() {
  local refs=${1:-} with_palette=${2:-1}
  [[ -n "$refs" && "$refs" != "[]" ]] || return 0
  local n i path desc aspect orient pal L S tone out=""
  n=$(printf '%s' "$refs" | jq 'length')
  for (( i=0; i<n; i++ )); do
    desc=$(printf '%s' "$refs"   | jq -r ".[$i].description // \"\"")
    aspect=$(printf '%s' "$refs" | jq -r ".[$i].aspect // \"\"")
    orient=$(printf '%s' "$refs" | jq -r ".[$i].orientation // \"\"")
    pal=$(printf '%s' "$refs"    | jq -r ".[$i].palette // [] | .[0:5] | join(\", \")")
    L=$(printf '%s' "$refs"      | jq -r ".[$i].lightness // \"\"")
    S=$(printf '%s' "$refs"      | jq -r ".[$i].saturation // \"\"")
    tone=$(tone_words "$L" "$S")
    local line="Style reference (visual similarity only, not image-to-image)"
    (( n > 1 )) && line="Style reference $((i+1)) (visual similarity only, not image-to-image)"
    line="$line: ${desc:-unspecified subject}."
    [[ "$with_palette" == "1" && -n "$pal" ]] && line="$line Dominant palette: $pal."
    [[ -n "$tone" ]] && line="$line Overall tone: $tone."
    [[ -n "$aspect" ]] && line="$line Source framing: $aspect $orient."
    out="${out:+$out$'\n'}$line"
  done
  printf '%s' "$out"
}

# ---------------------------------------------------------------- menu state

M_MODEL=""
M_MODEL_SRC="unset"
M_RATIO="1:1"
M_TIER="1K"
M_OUTDIR="./out"
M_OUTDIR_SET=0
M_UPSCALE=""
M_PALETTE=1
M_MAXCALLS=4
M_NONINTERACTIVE=0
M_YES=0
M_DRYRUN=0
M_QUESTIONS=0
declare -a M_PROMPTS=()
declare -a M_REF_PATHS=()
declare -a M_REF_DESCS=()
MODELS_CACHE=""

is_tty() { [[ -t 0 && -t 1 ]] || [[ -n "${IMG_ASSUME_TTY:-}" ]]; }

ask() { # ask <varname> <prompt> [default]
  local __var=$1 __prompt=$2 __def=${3:-} __val=""
  if [[ -t 0 && -z "${IMG_ASSUME_TTY:-}" ]]; then
    IFS= read -r -e -i "$__def" -p "$__prompt" __val || __val=""
  else
    printf '%s' "$__prompt" >&2
    IFS= read -r __val || __val=""
    [[ -z "$__val" ]] && __val="$__def"
  fi
  printf -v "$__var" '%s' "$__val"
}

models_cache() {
  [[ -n "$MODELS_CACHE" ]] && { printf '%s' "$MODELS_CACHE"; return; }
  MODELS_CACHE=$(cmd_models)
  printf '%s' "$MODELS_CACHE"
}

refs_json() {
  local n=${#M_REF_PATHS[@]} i facts out="[]"
  (( n == 0 )) && { printf '[]'; return; }
  local -a items=()
  for (( i=0; i<n; i++ )); do
    facts=$(ref_facts "${M_REF_PATHS[$i]}")
    items+=("$(printf '%s' "$facts" | jq -c --arg d "${M_REF_DESCS[$i]:-}" '.description=$d')")
  done
  out=$(printf '%s\n' "${items[@]}" | jq -sc .)
  printf '%s' "$out"
}

compose_prompt() { # compose_prompt <prompt> <refs_json>
  local p=$1 refs=${2:-} brief
  brief=$(build_ref_brief "$refs" "$M_PALETTE")
  if [[ -n "$brief" ]]; then printf '%s\n\n%s' "$p" "$brief"; else printf '%s' "$p"; fi
}

# ---------------------------------------------------------------- menu screens

# Validate a user-typed slug for free via get-model. Shared by the router and
# the "manual" option inside the ranked browser.
menu_manual_slug() {
  local slug; ask slug "  slug: " "$M_MODEL"
  [[ -n "$slug" ]] || return
  local author rest resp
  author=${slug%%/*}; rest=${slug#*/}
  if [[ "$author" == "$slug" ]]; then err "slug must look like author/model"; return; fi
  resp=$(mcp_call get-model "$(jq -nc --arg a "$author" --arg s "$rest" '{request:{author:$a,slug:$s}}')" 2>/dev/null || true)
  if [[ -n "$(printf '%s' "$resp" | payload_error_text)" ]]; then
    err "model not found: $slug"
  else
    M_MODEL=$slug; M_MODEL_SRC="manual (validated)"
  fi
}

# Paged ranked list for one category, 5 rows per page, global 1-N numbering.
menu_browse_models() { # <price|speed|quality>
  local cat=$1 tsv per=5 page=0 total pages i start end
  local -a ids=() lines=()
  tsv=$(model_table "$cat" 20 2>/dev/null) || { err "no ranking data for $cat; pick auto or manual"; return; }
  local id pd elo win sp q
  while IFS=$'\t' read -r id pd elo win sp; do
    [[ -n "$id" ]] || continue
    if [[ "$elo" != "-" ]]; then q="$elo/$win"; else q="-"; fi
    ids+=("$id")
    lines+=("$(printf '%-40s %-15s %-10s %s' "$id" "$pd" "$q" "$sp")")
  done <<<"$tsv"
  total=${#ids[@]}
  (( total > 0 )) || { err "catalogue empty"; return; }
  pages=$(( (total + per - 1) / per ))
  while true; do
    ui ""
    ui "  Model by $cat - page $((page+1))/$pages   ($total models)"
    printf "      %-40s %-15s %-10s %s\n" "model" "price" "quality" "speed" >&2
    start=$((page*per)); end=$((start+per)); (( end > total )) && end=$total
    for (( i=start; i<end; i++ )); do
      printf "  %2d) %s\n" "$((i+1))" "${lines[$i]}" >&2
    done
    ui "  n) next   p) prev   m) manual slug   b) back"
    ui "  (price is per-token, NOT per-image; speed ~rN = throughput proxy - see SKILL.md)"
    local c; ask c "  number 1-$total (or n/p/m/b): " ""
    case "$c" in
      n|N) if (( page < pages-1 )); then page=$((page+1)); else err "last page"; fi;;
      p|P) if (( page > 0 )); then page=$((page-1)); else err "first page"; fi;;
      m|M) menu_manual_slug; [[ -n "$M_MODEL" ]] && return;;
      b|B|"") return;;
      *) if [[ "$c" =~ ^[0-9]+$ ]] && (( c >= 1 && c <= total )); then
           M_MODEL=${ids[$((c-1))]}; M_MODEL_SRC="$cat rank $c"; return
         else err "enter a number 1-$total, or n/p/m/b"; fi;;
    esac
  done
}

menu_pick_model() {
  ui ""
  ui "  Choose model by:"
  ui "    1) price    - cheapest first"
  ui "    2) speed    - fastest first (10 measured, rest ~throughput proxy)"
  ui "    3) quality  - highest design-arena elo first (measured only)"
  ui "    a) auto     - cheapest in the catalogue"
  ui "    m) manual   - type a slug"
  ui "    b) back"
  local c; ask c "  choice [a]: " "a"
  case "${c:-a}" in
    1) menu_browse_models price;;
    2) menu_browse_models speed;;
    3) menu_browse_models quality;;
    a|A)
      local first
      first=$(models_cache | awk 'NR==1{print $1}')
      [[ -n "$first" ]] || { err "catalogue empty"; return; }
      M_MODEL=$first; M_MODEL_SRC="auto: lowest catalogue price"
      ;;
    m|M) menu_manual_slug;;
    b|B|"") return;;
    *) err "unknown choice: $c";;
  esac
}

menu_refs() {
  while true; do
    ui ""
    ui "  References (MCP cannot send images; they become text in the prompt)"
    local i
    if (( ${#M_REF_PATHS[@]} == 0 )); then
      ui "    (none)"
    else
      for (( i=0; i<${#M_REF_PATHS[@]}; i++ )); do
        printf "    %d) %s\n       desc: %s\n" "$((i+1))" "${M_REF_PATHS[$i]}" "${M_REF_DESCS[$i]:-<empty>}" >&2
      done
    fi
    ui "  a) add   d) delete   p) palette in brief: $( ((M_PALETTE)) && echo yes || echo no )   b) back"
    local c; ask c "  choice: " "b"
    case "${c:-b}" in
      a|A)
        local path; ask path "  image path: " ""
        [[ -n "$path" ]] || continue
        path="${path/#\~/$HOME}"
        if [[ ! -f "$path" ]]; then err "not found: $path"; continue; fi
        local facts
        if ! facts=$(ref_facts "$path"); then err "cannot read image"; continue; fi
        local pal aspect orient L S tone prefill
        pal=$(printf '%s' "$facts" | jq -r '.palette | join(" ")')
        aspect=$(printf '%s' "$facts" | jq -r '.aspect')
        orient=$(printf '%s' "$facts" | jq -r '.orientation')
        L=$(printf '%s' "$facts" | jq -r '.lightness')
        S=$(printf '%s' "$facts" | jq -r '.saturation')
        tone=$(tone_words "$L" "$S")
        ui "  facts: $aspect $orient | tone: $tone | palette: $pal"
        prefill="subject and style: "
        local desc; ask desc "  describe subject/composition/medium: " "$prefill"
        desc=${desc#subject and style: }
        M_REF_PATHS+=("$path"); M_REF_DESCS+=("$desc")
        ;;
      d|D)
        local n; ask n "  number to delete: " ""
        if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#M_REF_PATHS[@]} )); then
          unset 'M_REF_PATHS[n-1]' 'M_REF_DESCS[n-1]'
          M_REF_PATHS=("${M_REF_PATHS[@]}"); M_REF_DESCS=("${M_REF_DESCS[@]}")
        fi
        ;;
      p|P) M_PALETTE=$(( M_PALETTE ? 0 : 1 ));;
      b|B|"") return;;
    esac
  done
}

menu_pick_from_list() { # menu_pick_from_list <varname> <current> <items...>
  local __var=$1 cur=$2; shift 2
  local -a items=("$@")
  local i
  ui ""
  for (( i=0; i<${#items[@]}; i++ )); do
    local mark=" "; [[ "${items[$i]}" == "$cur" ]] && mark="*"
    printf "  %s %d) %s\n" "$mark" "$((i+1))" "${items[$i]}" >&2
  done
  local n; ask n "  number: " ""
  if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#items[@]} )); then
    printf -v "$__var" '%s' "${items[$((n-1))]}"
  fi
}

menu_prompts() {
  while true; do
    ui ""
    local i
    if (( ${#M_PROMPTS[@]} == 0 )); then
      ui "  (no prompts)"
    else
      for (( i=0; i<${#M_PROMPTS[@]}; i++ )); do
        printf "  %d) %s\n" "$((i+1))" "$(printf '%.100s' "${M_PROMPTS[$i]}")" >&2
      done
    fi
    ui "  a) add   e) edit in \$EDITOR   f) load from file   d) delete   b) back"
    local c; ask c "  choice: " "b"
    case "${c:-b}" in
      a|A) local p; ask p "  prompt: " ""; [[ -n "$p" ]] && M_PROMPTS+=("$p");;
      e|E)
        local ed=${EDITOR:-nano} tf
        tf=$(mktemp)
        (( ${#M_PROMPTS[@]} > 0 )) && printf '%s\n' "${M_PROMPTS[@]}" > "$tf"
        if command -v "$ed" >/dev/null 2>&1 && [[ -t 0 ]]; then
          "$ed" "$tf" </dev/tty >/dev/tty 2>&1 || true
          M_PROMPTS=()
          while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && M_PROMPTS+=("$line")
          done < "$tf"
        else
          err "no usable \$EDITOR / not a terminal"
        fi
        rm -f "$tf"
        ;;
      f|F)
        local pf; ask pf "  file (one prompt per line): " ""
        pf="${pf/#\~/$HOME}"
        if [[ -f "$pf" ]]; then
          while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -n "$line" ]] && M_PROMPTS+=("$line")
          done < "$pf"
        else err "not found: $pf"; fi
        ;;
      d|D)
        local n; ask n "  number to delete: " ""
        if [[ "$n" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#M_PROMPTS[@]} )); then
          unset 'M_PROMPTS[n-1]'; M_PROMPTS=("${M_PROMPTS[@]}")
        fi
        ;;
      b|B|"") return;;
    esac
  done
}

menu_upscale_existing() {
  ui ""
  local pat; ask pat "  file or glob: " ""
  [[ -n "$pat" ]] || return
  pat="${pat/#\~/$HOME}"
  local -a files=()
  local g
  # shellcheck disable=SC2086
  for g in $pat; do [[ -f "$g" ]] && files+=("$g"); done
  if (( ${#files[@]} == 0 )); then err "nothing matched: $pat"; return; fi
  local fct; ask fct "  factor 2 or 4 [2]: " "2"
  case "${fct:-2}" in 2|4) ;; *) err "factor must be 2 or 4"; return;; esac
  local f out
  for f in "${files[@]}"; do
    if out=$(cmd_upscale "$f" "${fct:-2}"); then
      ui "  -> $out"
      printf '%s\n' "$out"
    fi
  done
}

# ---------------------------------------------------------------- output dir

# Expands ~, creates the directory, verifies it is writable, prints the absolute
# path. Returns 1 instead of dying so the picker can re-ask.
resolve_outdir() {
  local p=${1:-}
  [[ -n "$p" ]] || { err "empty path"; return 1; }
  p="${p/#\~/$HOME}"
  if [[ -e "$p" && ! -d "$p" ]]; then err "exists but is not a directory: $p"; return 1; fi
  mkdir -p "$p" 2>/dev/null || { err "cannot create directory: $p"; return 1; }
  [[ -w "$p" ]] || { err "directory is not writable: $p"; return 1; }
  (cd -- "$p" && pwd)
}

# mode: initial (asked once at menu startup) | change (reached from the menu)
menu_pick_outdir() {
  local mode=${1:-change} c path resolved
  while true; do
    ui ""
    ui "  Where should the images be saved?"
    printf "    1) current directory  : %s\n" "$PWD" >&2
    ui  "    2) custom path..."
    printf "    3) ./out subdirectory : %s\n" "$PWD/out" >&2
    [[ "$mode" == "change" ]] && ui "    b) keep $M_OUTDIR"
    ask c "  choice [1]: " "1"
    path=""
    case "${c:-1}" in
      1) path="$PWD";;
      2) ask path "  path: " ""
         [[ -n "$path" ]] || { err "no path given"; continue; };;
      3) path="$PWD/out";;
      b|B) if [[ "$mode" == "change" ]]; then return 0; fi
           err "unknown choice: $c"; continue;;
      q|Q) if [[ "$mode" == "initial" ]]; then ui "  bye, nothing spent"; exit 0; fi
           err "unknown choice: $c"; continue;;
      *) err "unknown choice: $c"; continue;;
    esac
    if resolved=$(resolve_outdir "$path"); then
      M_OUTDIR=$resolved
      M_OUTDIR_SET=1
      info "  images -> $M_OUTDIR"
      return 0
    fi
  done
}

menu_summary() {
  local size calls
  size=$(cmd_size "$M_RATIO" "$M_TIER" 2>/dev/null || echo "?")
  calls=${#M_PROMPTS[@]}
  ui ""
  ui "=============== img.sh menu ==============="
  printf "  1) Model            : %s   [%s]\n" "${M_MODEL:-<unset>}" "$M_MODEL_SRC" >&2
  printf "  2) References       : %d (palette in brief: %s)\n" "${#M_REF_PATHS[@]}" "$( ((M_PALETTE)) && echo yes || echo no )" >&2
  printf "  3) Aspect ratio     : %s\n" "$M_RATIO" >&2
  printf "  4) Resolution       : %-4s -> %s\n" "$M_TIER" "$size" >&2
  printf "  5) Prompts          : %d\n" "$calls" >&2
  printf "  6) Upscale after gen: %s\n" "${M_UPSCALE:-off}" >&2
  ui "  7) Upscale an existing image..."
  ui "  8) Output dir       : $M_OUTDIR"
  printf "  g) Generate         (%d paid call(s))\n" "$calls" >&2
  ui "  q) Quit"
  ui "==========================================="
}

menu_equivalent_cmd() {
  local out="$SELF menu --non-interactive --yes -m ${M_MODEL:-MODEL} -r $M_RATIO -q $M_TIER -o $(printf '%q' "$M_OUTDIR")"
  [[ -n "$M_UPSCALE" ]] && out="$out --upscale $M_UPSCALE"
  (( M_PALETTE )) || out="$out --no-palette"
  local i
  for (( i=0; i<${#M_REF_PATHS[@]}; i++ )); do
    out="$out --ref $(printf '%q' "${M_REF_PATHS[$i]}") --ref-desc $(printf '%q' "${M_REF_DESCS[$i]:-}")"
  done
  for (( i=0; i<${#M_PROMPTS[@]}; i++ )); do
    out="$out --prompt $(printf '%q' "${M_PROMPTS[$i]}")"
  done
  printf '%s' "$out"
}

menu_run() {
  [[ -n "$M_MODEL" ]] || { err "no model selected"; return 1; }
  (( ${#M_PROMPTS[@]} > 0 )) || { err "no prompts"; return 1; }
  if (( ${#M_PROMPTS[@]} > M_MAXCALLS )); then
    err "${#M_PROMPTS[@]} prompts exceeds --max-calls $M_MAXCALLS; raise it deliberately"
    return 1
  fi
  local refs finals=() p
  refs=$(refs_json)
  for p in "${M_PROMPTS[@]}"; do finals+=("$(compose_prompt "$p" "$refs")"); done

  local -a gen_args=(-m "$M_MODEL" -r "$M_RATIO" -q "$M_TIER" -o "$M_OUTDIR")
  [[ -n "$M_UPSCALE" ]] && gen_args+=(--upscale "$M_UPSCALE")
  [[ "$refs" != "[]" ]] && gen_args+=(--refs-json "$refs")

  info "About to make ${#finals[@]} paid MCP call(s) on $M_MODEL."
  cmd_gen "${gen_args[@]}" -- "${finals[@]}"
}

menu_plan() {
  local size refs p i
  size=$(cmd_size "$M_RATIO" "$M_TIER" 2>/dev/null || echo "?")
  refs=$(refs_json)
  echo "plan (nothing has been generated yet):"
  echo "  model      : ${M_MODEL:-<unset>}"
  echo "  ratio/tier : $M_RATIO / $M_TIER -> size=$size"
  echo "  outdir     : $M_OUTDIR"
  echo "  upscale    : ${M_UPSCALE:-off}"
  echo "  paid calls : ${#M_PROMPTS[@]} (max-calls $M_MAXCALLS)"
  echo "  references : $(printf '%s' "$refs" | jq 'length')"
  for (( i=0; i<${#M_PROMPTS[@]}; i++ )); do
    echo "  --- final prompt $((i+1)) ---"
    compose_prompt "${M_PROMPTS[$i]}" "$refs"
    echo
  done
  # A plan is not a deliverable. Spell out the one command that produces a file,
  # otherwise this output gets mistaken for the finished job.
  echo "NEXT STEP - required to actually create the image, run this exact command:"
  echo "  $(menu_equivalent_cmd)"
}

write_pending_refs() {
  mkdir -p "$M_OUTDIR"
  local f="$M_OUTDIR/refs.pending.json" i facts
  local -a items=()
  for (( i=0; i<${#M_REF_PATHS[@]}; i++ )); do
    facts=$(ref_facts "${M_REF_PATHS[$i]}")
    items+=("$(printf '%s' "$facts" | jq -c --arg d "${M_REF_DESCS[$i]:-}" '.description=$d')")
  done
  printf '%s\n' "${items[@]}" | jq -s '{note:"Describe each reference (subject, composition, medium, style), then re-run with --ref-desc in the same order. MCP cannot receive images; the description becomes text in the prompt.", refs:.}' > "$f"
  printf '%s\n' "$f"
}

# A fixed questionnaire an agent relays to the user when they ask for the menu
# but there is no TTY. Deterministic on purpose: same text for every model, so
# a weak one has nothing to improvise. Prints to stdout, needs no TTY.
menu_questions() {
  cat <<EOF
Ask the user these, then generate. Values in [] are defaults - keep them if the user does not care.
  1) Prompt      : (required) what to draw, in English, be specific
  2) Aspect ratio: [16:9]  one of 1:1 16:9 9:16 4:3 3:4 21:9
  3) Resolution  : [2K]    one of 1K 2K 4K
  4) Output dir  : [current directory]  any path
  5) Model       : [black-forest-labs/flux.2-klein-4b]  only if the user wants another
Then run (one --prompt per image):
  $SELF menu --non-interactive --yes -m <model> -r <ratio> -q <tier> -o <dir> --prompt "<prompt>"
EOF
}

cmd_menu() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --non-interactive) M_NONINTERACTIVE=1; shift;;
      --questions) M_QUESTIONS=1; shift;;
      --yes|-y) M_YES=1; shift;;
      --dry-run) M_DRYRUN=1; shift;;
      --max-calls) M_MAXCALLS=${2:-4}; shift 2;;
      -m|--model) M_MODEL=${2:-}; M_MODEL_SRC="flag"; shift 2;;
      -r|--ratio) M_RATIO=${2:-}; shift 2;;
      -q|--tier)  M_TIER=${2:-}; shift 2;;
      -o|--out)   M_OUTDIR=${2:-}; M_OUTDIR_SET=1; shift 2;;
      --prompt)   M_PROMPTS+=("${2:-}"); shift 2;;
      --ref)      M_REF_PATHS+=("${2:-}"); shift 2;;
      --ref-desc) M_REF_DESCS+=("${2:-}"); shift 2;;
      --no-palette) M_PALETTE=0; shift;;
      --upscale)  M_UPSCALE=${2:-}; shift 2;;
      -h|--help)  help; exit 0;;
      *) die "Unknown menu option: $1";;
    esac
  done

  [[ "$M_MAXCALLS" =~ ^[0-9]+$ ]] || die "--max-calls must be a number"
  [[ -z "$M_UPSCALE" || "$M_UPSCALE" == "2" || "$M_UPSCALE" == "4" ]] || die "--upscale must be 2 or 4"

  # The questionnaire works with or without a TTY and never spends anything.
  if (( M_QUESTIONS )); then menu_questions; return 0; fi

  if (( M_NONINTERACTIVE )); then
    local i
    for (( i=0; i<${#M_REF_PATHS[@]}; i++ )); do
      [[ -f "${M_REF_PATHS[$i]}" ]] || die "Reference not found: ${M_REF_PATHS[$i]}"
    done
    # A reference without words cannot reach the model; ask the agent to fill it in.
    if (( ${#M_REF_PATHS[@]} > 0 )); then
      local missing=0
      for (( i=0; i<${#M_REF_PATHS[@]}; i++ )); do
        [[ -n "${M_REF_DESCS[$i]:-}" ]] || missing=1
      done
      if (( missing )); then
        local f; f=$(write_pending_refs)
        err "reference(s) without --ref-desc. Wrote $f - describe each ref, then re-run with --ref-desc in the same order. Nothing was spent."
        exit $EX_PENDING_REFS
      fi
    fi
    [[ -n "$M_MODEL" ]] || die "--model is required in non-interactive mode"
    (( ${#M_PROMPTS[@]} > 0 )) || die "at least one --prompt is required in non-interactive mode"
    if (( M_DRYRUN || ! M_YES )); then
      (( M_YES )) || info "DRY-RUN ONLY - NO IMAGE WAS CREATED. NOTHING WAS SPENT."
      menu_plan
      return 0
    fi
    menu_run
    return $?
  fi

  if ! is_tty; then
    err "'menu' is interactive and needs a TTY (exit $EX_NO_TTY)."
    err "AGENT: do not hand this back to the user. Run '$SELF menu --questions',"
    err "  ask the user those questions, then run 'menu --non-interactive --yes ...'."
    err "HUMAN: for the full interactive picker, run '$SELF menu' in your own terminal."
    exit $EX_NO_TTY
  fi

  # First question of the session: where do the images go. Skipped when -o was given.
  (( M_OUTDIR_SET )) || menu_pick_outdir initial

  while true; do
    menu_summary
    local c; ask c "  choice: " ""
    case "$c" in
      1) menu_pick_model;;
      2) menu_refs;;
      3) menu_pick_from_list M_RATIO "$M_RATIO" "${RATIO_LIST[@]}";;
      4) menu_pick_from_list M_TIER "$M_TIER" "${TIER_LIST[@]}";;
      5) menu_prompts;;
      6) local u; ask u "  upscale after gen (off/2/4) [off]: " "off"
         case "${u:-off}" in off|"") M_UPSCALE="";; 2) M_UPSCALE=2;; 4) M_UPSCALE=4;; *) err "off, 2 or 4";; esac;;
      7) menu_upscale_existing;;
      8) menu_pick_outdir change;;
      g|G)
        if [[ -z "$M_MODEL" ]]; then err "pick a model first (option 1)"; continue; fi
        if (( ${#M_PROMPTS[@]} == 0 )); then err "add at least one prompt first (option 5)"; continue; fi
        # IMG_ASSUME_TTY is a test hook, not a way to spend money from a fake TTY.
        if [[ -n "${IMG_ASSUME_TTY:-}" ]]; then
          err "IMG_ASSUME_TTY is set: refusing to spend. Use 'menu --non-interactive --yes' to generate."
          continue
        fi
        local size; size=$(cmd_size "$M_RATIO" "$M_TIER" 2>/dev/null || echo "?")
        ui ""
        ui "  About to spend: ${#M_PROMPTS[@]} paid call(s)"
        ui "  model: ${M_MODEL:-<unset>}   size: $size   outdir: $M_OUTDIR"
        ui "  (no price estimate: the catalogue value is per-token, not per-image)"
        local yn; ask yn "  proceed? [y/N]: " "N"
        case "$yn" in
          y|Y|yes|YES)
            if menu_run; then ui "  ok"; else err "generation reported failures"; fi
            ui ""
            ui "  equivalent command:"
            ui "  $(menu_equivalent_cmd)"
            ;;
          *) ui "  aborted, nothing spent";;
        esac
        ;;
      q|Q) ui "  bye"; return 0;;
      "") ;;
      *) err "unknown choice: $c";;
    esac
  done
}

# ---------------------------------------------------------------- dispatch

case "${1:-}" in
  menu)     shift; cmd_menu "$@";;
  mcp)      shift; mcp_call "$@";;
  models)   shift; cmd_models "$@";;
  size)     shift; cmd_size "$@";;
  gen)      shift; cmd_gen "$@";;
  extract)  shift; cmd_extract "$@";;
  upscale)  shift; cmd_upscale "$@";;
  reffacts) shift; ref_facts "$@";;
  -h|--help|help|"") help;;
  *) die "Unknown command: ${1:-}";;
esac
