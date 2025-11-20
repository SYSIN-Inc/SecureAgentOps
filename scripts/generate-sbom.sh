#!/usr/bin/env bash
# Generate SBOMs for all components in the project
# Usage: ./scripts/generate-all-sboms.sh [output_directory]

# Prevent infinite loops (only check, don't export to child processes)
if [[ "${GENERATE_ALL_SBOMS_RUNNING:-}" == "1" ]]; then
  echo "❌ Error: generate-all-sboms.sh is already running. Preventing infinite loop."
  exit 1
fi
GENERATE_ALL_SBOMS_RUNNING=1

set -euo pipefail

# Get script directory and project root first
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Set output directory (must be relative to project root or absolute)
if [[ -n "${1:-}" ]]; then
  # If argument is provided, use it (but make it absolute if relative)
  if [[ "${1}" = /* ]]; then
    OUTPUT_DIR="${1}"
  else
    OUTPUT_DIR="${PROJECT_ROOT}/${1}"
  fi
else
  OUTPUT_DIR="${PROJECT_ROOT}/sboms/$(date +%Y%m%d-%H%M%S)"
fi

echo "=========================================="
echo "  SecureAgentOps - Generate All SBOMs"
echo "=========================================="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Try to use generate-sbom-direct.sh first (more reliable), fallback to generate-sbom.sh
GENERATE_SBOM_SCRIPT="$SCRIPT_DIR/generate-sbom-direct.sh"
if [[ ! -f "$GENERATE_SBOM_SCRIPT" ]]; then
  GENERATE_SBOM_SCRIPT="$SCRIPT_DIR/generate-sbom.sh"
fi
if [[ ! -f "$GENERATE_SBOM_SCRIPT" ]]; then
  echo "❌ Error: generate-sbom.sh not found at $GENERATE_SBOM_SCRIPT"
  echo "   Script directory: $SCRIPT_DIR"
  echo "   Current directory: $(pwd)"
  exit 1
fi

# Verify it's not a symlink to this script
if [[ -L "$GENERATE_SBOM_SCRIPT" ]]; then
  LINK_TARGET=$(readlink -f "$GENERATE_SBOM_SCRIPT")
  THIS_SCRIPT=$(readlink -f "${BASH_SOURCE[0]}")
  if [[ "$LINK_TARGET" == "$THIS_SCRIPT" ]]; then
    echo "❌ Error: generate-sbom.sh is a symlink to generate-all-sboms.sh!"
    echo "   This will cause an infinite loop. Please fix the symlink."
    exit 1
  fi
fi

# Verify the script content - check first line doesn't say "Generate All SBOMs"
FIRST_LINE=$(head -n 1 "$GENERATE_SBOM_SCRIPT" 2>/dev/null || echo "")
if echo "$FIRST_LINE" | grep -q "Generate All SBOMs\|generate-all-sboms"; then
  echo "❌ Error: generate-sbom.sh appears to contain generate-all-sboms.sh content!"
  echo "   First line: $FIRST_LINE"
  echo "   This will cause an infinite loop. Please check the file content."
  exit 1
fi

# Make sure it's executable
chmod +x "$GENERATE_SBOM_SCRIPT" 2>/dev/null || true

# Generate SBOM for gatekeeper
echo "📦 Generating SBOM for gatekeeper..."
if [[ -d "$PROJECT_ROOT/gatekeeper" ]]; then
  # Unset the guard variable and use env to ensure clean environment
  unset GENERATE_ALL_SBOMS_RUNNING
  OUTPUT_FILE="$OUTPUT_DIR/gatekeeper.json"
  echo "  Calling: bash $GENERATE_SBOM_SCRIPT \"$PROJECT_ROOT/gatekeeper\" \"$OUTPUT_FILE\""
  if env -u GENERATE_ALL_SBOMS_RUNNING bash "$GENERATE_SBOM_SCRIPT" "$PROJECT_ROOT/gatekeeper" "$OUTPUT_FILE" 2>&1; then
    echo "  ✅ Gatekeeper SBOM generated successfully"
  else
    EXIT_CODE=$?
    echo "  ⚠️  Failed to generate gatekeeper SBOM (exit code: $EXIT_CODE)"
  fi
  # Restore guard for next iteration
  GENERATE_ALL_SBOMS_RUNNING=1
else
  echo "⚠️  Gatekeeper directory not found at $PROJECT_ROOT/gatekeeper"
fi

# Generate SBOMs for all agents
echo ""
echo "📦 Generating SBOMs for agents..."
if [[ -d "$PROJECT_ROOT/agents" ]]; then
  for agent_dir in "$PROJECT_ROOT/agents"/*/; do
    if [[ -d "$agent_dir" ]]; then
      agent_name=$(basename "$agent_dir")
      echo "  Generating SBOM for: $agent_name"
      # Unset the guard variable and use env to ensure clean environment
      unset GENERATE_ALL_SBOMS_RUNNING
      OUTPUT_FILE="$OUTPUT_DIR/${agent_name}.json"
      if env -u GENERATE_ALL_SBOMS_RUNNING bash "$GENERATE_SBOM_SCRIPT" "$agent_dir" "$OUTPUT_FILE" 2>&1; then
        echo "    ✅ $agent_name SBOM generated successfully"
      else
        EXIT_CODE=$?
        echo "    ⚠️  Failed to generate SBOM for $agent_name (exit code: $EXIT_CODE)"
      fi
      # Restore guard for next iteration
      GENERATE_ALL_SBOMS_RUNNING=1
    fi
  done
else
  echo "⚠️  Agents directory not found"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SBOM Generation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

SBOM_COUNT=$(find "$OUTPUT_DIR" -name "*.json" 2>/dev/null | wc -l || echo "0")
echo "✅ Generated $SBOM_COUNT SBOM file(s)"
echo "📁 Output directory: $OUTPUT_DIR"
echo ""

if [[ "$SBOM_COUNT" -gt 0 ]]; then
  echo "Generated SBOMs:"
  find "$OUTPUT_DIR" -name "*.json" -exec basename {} \; | sed 's/^/  • /'
  echo ""
  
  # Show component counts if jq is available
  if command -v jq >/dev/null 2>&1; then
    echo "Component counts:"
    for sbom_file in "$OUTPUT_DIR"/*.json; do
      if [[ -f "$sbom_file" ]]; then
        component_count=$(jq '.components | length' "$sbom_file" 2>/dev/null || echo "0")
        echo "  • $(basename "$sbom_file"): $component_count components"
      fi
    done
  fi
fi

echo ""
echo "✅ SBOM generation complete!"

