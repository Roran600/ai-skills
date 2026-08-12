#!/bin/bash

##############################################################################
# IMAGE GENERATION SKILL - BASH UTILITIES
# Utility functions only - main workflow is in SKILL.md
# Source this file: source ./image-gen.sh
##############################################################################

# 1. Decode base64 + save PNG (KRITICKÉ - MCP response format)
save_image() {
  local base64_data="$1"
  local output_file="$2"
  
  if echo "$base64_data" | base64 -d > "$output_file" 2>/dev/null; then
    return 0
  else
    echo "❌ Error: Cannot decode base64 to PNG" >&2
    return 1
  fi
}

# 2. Ensure directory exists (create if needed)
ensure_dir() {
  local dir_path="$1"
  if ! mkdir -p "$dir_path" 2>/dev/null; then
    echo "❌ Error: Cannot create directory: $dir_path" >&2
    return 1
  fi
}

# 3. Generate timestamp (YYYYMMDD_HHMMSS format)
get_timestamp() {
  date +%Y%m%d_%H%M%S
}

# 4. Extract model short name from slug
get_model_short_name() {
  echo "$1" | rev | cut -d'/' -f1 | rev | cut -c1-20
}

# 5. Create metadata JSON
create_metadata_json() {
  local filename="$1"
  local prompt="$2"
  local model="$3"
  local gen_id="$4"
  local cost="$5"
  local duration="${6:-0}"
  
  cat <<EOF
{
  "filename": "$filename",
  "prompt": "$prompt",
  "model_used": "$model",
  "generation_id": "$gen_id",
  "source": "openrouter-mcp-inline",
  "generation": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "duration_ms": $duration,
    "cost_usd": $cost
  }
}
EOF
}

# 6. Validate prompt (security - anti-injection)
validate_prompt() {
  local prompt="$1"
  local len=${#prompt}
  
  # Length check (5-1500 chars)
  if (( len < 5 || len > 1500 )); then
    echo "❌ Error: Prompt length must be 5-1500 characters (got $len)" >&2
    return 1
  fi
  
  # SQL Injection detection
  if [[ "$prompt" =~ (SELECT|DROP|DELETE|INSERT|UPDATE|CREATE|ALTER|UNION|'--'|'/*'|'*/') ]]; then
    echo "❌ Error: SQL injection detected" >&2
    return 1
  fi
  
  # Command Injection detection
  if [[ "$prompt" =~ [\`\|\;] ]] || [[ "$prompt" =~ \$\( ]]; then
    echo "❌ Error: Command injection detected" >&2
    return 1
  fi
  
  # Path Traversal detection
  if [[ "$prompt" =~ \.\.\/ ]] || [[ "$prompt" =~ ~\/ ]]; then
    echo "❌ Error: Path traversal detected" >&2
    return 1
  fi
  
  # Null byte detection
  if [[ "$prompt" =~ $'\x00' ]]; then
    echo "❌ Error: Null byte detected" >&2
    return 1
  fi
  
  return 0
}

# Export functions for sourcing
export -f save_image
export -f ensure_dir
export -f get_timestamp
export -f get_model_short_name
export -f create_metadata_json
export -f validate_prompt
