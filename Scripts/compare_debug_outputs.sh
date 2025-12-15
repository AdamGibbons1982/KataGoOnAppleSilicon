#!/bin/bash

# Script to compare Swift vs KataGo C++ debug outputs
# Generates a comparison report highlighting differences

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEBUG_DIR="$PROJECT_ROOT/.cursor/debug"
COMPARISON_REPORT="$DEBUG_DIR/comparison_report.txt"

# Tolerance for floating point comparisons
TOLERANCE=0.000001

echo -e "${GREEN}=== Debug Output Comparison Tool ===${NC}"
echo ""

# Create debug directory if it doesn't exist
mkdir -p "$DEBUG_DIR"

# Initialize comparison report
{
    echo "=== Debug Output Comparison Report ==="
    echo "Generated at: $(date)"
    echo ""
} > "$COMPARISON_REPORT"

# Function to compare two files
compare_files() {
    local swift_file="$1"
    local katago_file="$2"
    local description="$3"
    
    if [ ! -f "$swift_file" ]; then
        echo -e "${RED}✗ Swift file not found: $swift_file${NC}"
        echo "✗ Swift file not found: $swift_file" >> "$COMPARISON_REPORT"
        return 1
    fi
    
    if [ ! -f "$katago_file" ]; then
        echo -e "${RED}✗ KataGo file not found: $katago_file${NC}"
        echo "✗ KataGo file not found: $katago_file" >> "$COMPARISON_REPORT"
        return 1
    fi
    
    echo -e "${BLUE}Comparing: $description${NC}"
    echo "=== $description ===" >> "$COMPARISON_REPORT"
    
    # Use diff with numeric comparison where possible
    # For now, use standard diff and highlight differences
    local diff_output=$(diff -u "$swift_file" "$katago_file" || true)
    
    if [ -z "$diff_output" ]; then
        echo -e "${GREEN}✓ Files match exactly${NC}"
        echo "✓ Files match exactly" >> "$COMPARISON_REPORT"
        return 0
    else
        echo -e "${YELLOW}⚠ Files differ (showing first 50 lines of diff)${NC}"
        echo "⚠ Files differ:" >> "$COMPARISON_REPORT"
        echo "$diff_output" | head -50 >> "$COMPARISON_REPORT"
        echo "..." >> "$COMPARISON_REPORT"
        return 1
    fi
    
    echo "" >> "$COMPARISON_REPORT"
}

# Compare input features
echo -e "${YELLOW}=== Comparing Input Features ===${NC}"
compare_files \
    "$DEBUG_DIR/swift_inputs_spatial.txt" \
    "$DEBUG_DIR/katago_coreml_inputs_spatial.txt" \
    "Spatial Input Features"

compare_files \
    "$DEBUG_DIR/swift_inputs_global.txt" \
    "$DEBUG_DIR/katago_coreml_inputs_global.txt" \
    "Global Input Features"

echo ""

# Compare raw outputs
echo -e "${YELLOW}=== Comparing Raw Model Outputs ===${NC}"
compare_files \
    "$DEBUG_DIR/swift_raw_policy.txt" \
    "$DEBUG_DIR/katago_coreml_raw_policy.txt" \
    "Raw Policy Output"

compare_files \
    "$DEBUG_DIR/swift_raw_value.txt" \
    "$DEBUG_DIR/katago_coreml_raw_value.txt" \
    "Raw Value Output"

compare_files \
    "$DEBUG_DIR/swift_raw_ownership.txt" \
    "$DEBUG_DIR/katago_coreml_raw_ownership.txt" \
    "Raw Ownership Output"

if [ -f "$DEBUG_DIR/swift_raw_miscvalue.txt" ] && [ -f "$DEBUG_DIR/katago_coreml_raw_miscvalue.txt" ]; then
    compare_files \
        "$DEBUG_DIR/swift_raw_miscvalue.txt" \
        "$DEBUG_DIR/katago_coreml_raw_miscvalue.txt" \
        "Raw MiscValue Output"
fi

if [ -f "$DEBUG_DIR/swift_raw_moremiscvalue.txt" ] && [ -f "$DEBUG_DIR/katago_coreml_raw_moremiscvalue.txt" ]; then
    compare_files \
        "$DEBUG_DIR/swift_raw_moremiscvalue.txt" \
        "$DEBUG_DIR/katago_coreml_raw_moremiscvalue.txt" \
        "Raw MoreMiscValue Output"
fi

echo ""

# Compare postprocessed outputs
echo -e "${YELLOW}=== Comparing Postprocessed Outputs ===${NC}"
compare_files \
    "$DEBUG_DIR/swift_postprocessed_policy.txt" \
    "$DEBUG_DIR/katago_postprocessed.txt" \
    "Postprocessed Policy (partial - full comparison needs manual review)"

compare_files \
    "$DEBUG_DIR/swift_postprocessed_value.txt" \
    "$DEBUG_DIR/katago_postprocessed.txt" \
    "Postprocessed Value (partial - full comparison needs manual review)"

compare_files \
    "$DEBUG_DIR/swift_postprocessed_ownership.txt" \
    "$DEBUG_DIR/katago_postprocessed.txt" \
    "Postprocessed Ownership (partial - full comparison needs manual review)"

echo ""
echo -e "${GREEN}=== Comparison Complete ===${NC}"
echo -e "Full report saved to: ${BLUE}$COMPARISON_REPORT${NC}"

