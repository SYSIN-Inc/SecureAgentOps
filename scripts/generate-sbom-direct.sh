#!/usr/bin/env bash
# Direct SBOM generation using Trivy (bypasses generate-sbom.sh)
# Usage: ./scripts/generate-sbom-direct.sh <agent_path> <output_file.json>

AGENT_PATH=${1:-""}
OUTPUT_FILE=${2:-""}

if [[ -z "$AGENT_PATH" ]] || [[ -z "$OUTPUT_FILE" ]]; then
  echo "Usage: $0 <agent_path> <output_file.json>"
  exit 1
fi

if [[ ! -d "$AGENT_PATH" ]]; then
  echo "❌ Error: Agent path does not exist: $AGENT_PATH"
  exit 1
fi

# Ensure output file is not a directory
if [[ -d "$OUTPUT_FILE" ]]; then
  echo "❌ Error: Output path is a directory, not a file: $OUTPUT_FILE"
  echo "   Please specify a file path like: ${OUTPUT_FILE}.json"
  exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
mkdir -p "$OUTPUT_DIR"

# Find Trivy
TRIVY_CMD=""
for trivy_path in trivy /usr/local/bin/trivy /usr/bin/trivy; do
  if command -v "$trivy_path" >/dev/null 2>&1; then
    TRIVY_CMD="$trivy_path"
    break
  fi
done

if [[ -z "$TRIVY_CMD" ]]; then
  echo "❌ Error: Trivy not found"
  exit 1
fi

echo "Generating SBOM for: $AGENT_PATH"
echo "Output: $OUTPUT_FILE"

# Generate SBOM directly with Trivy
if $TRIVY_CMD fs --format cyclonedx --output "$OUTPUT_FILE" --quiet "$AGENT_PATH" 2>&1; then
  echo "✅ SBOM generated successfully: $OUTPUT_FILE"
  
  # Add metadata if jq is available
  if command -v jq >/dev/null 2>&1; then
    AGENT_NAME=$(basename "$AGENT_PATH")
    jq \
      --arg name "$AGENT_NAME" \
      --arg version "1.0.0" \
      --arg path "$AGENT_PATH" \
      '.metadata.component.name = $name |
       .metadata.component.version = $version |
       .metadata.component.properties = [
         {"name": "agent_path", "value": $path},
         {"name": "generated_by", "value": "SecureAgentOps"},
         {"name": "generated_locally", "value": "true"}
       ]' \
      "$OUTPUT_FILE" > "${OUTPUT_FILE}.tmp" && mv "${OUTPUT_FILE}.tmp" "$OUTPUT_FILE"
  fi
  
  # Show summary
  if command -v jq >/dev/null 2>&1; then
    COMPONENT_COUNT=$(jq '.components | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
    echo "  Components: $COMPONENT_COUNT"
  fi
else
  echo "❌ Error: Failed to generate SBOM"
  exit 1
fi


