#!/bin/bash
# Build help text by substituting placeholders in the common help template
#
# Usage: build-help.sh <output_file> <help_dir> <parent>
#
# Arguments:
#   output_file - Where to write the generated help
#   help_dir    - Directory containing help files (command_title.txt, abstract.txt, etc.)
#   parent      - Parent command name (create, display, etc.) or empty for top-level
#
# The script substitutes these placeholders:
#   @@@COMMAND TITLE@@@ - from help_dir/command_title.txt
#   @@@ABSTRACT@@@      - from help_dir/abstract.txt
#   @@@SYNTAX@@@        - from help_dir/syntax.txt
#   @@@SCA OPTIONS@@@   - from src/help/options.txt
#   @@@<PARENT> OPTIONS@@@ - from src/<parent>/help/options.txt (if parent specified)
#   @@@OPTIONS@@@       - from help_dir/options.txt
#   @@@FURTHER READ@@@  - from parent's further_read.txt or help_dir/further_read.txt

set -e

OUTPUT_FILE="$1"
HELP_DIR="$2"
PARENT="$3"

if [ -z "$OUTPUT_FILE" ] || [ -z "$HELP_DIR" ]; then
    echo "Usage: $0 <output_file> <help_dir> [parent]" >&2
    exit 1
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Determine further_read location (use parent's if exists, otherwise own)
if [ -n "$PARENT" ] && [ -f "src/${PARENT}/help/further_read.txt" ]; then
    FURTHER_READ="src/${PARENT}/help/further_read.txt"
else
    FURTHER_READ="${HELP_DIR}/further_read.txt"
fi

# Build the help file using sed substitutions
cat build/common/help/help.txt | \
    sed -e "/@@@COMMAND TITLE@@@/{r ${HELP_DIR}/command_title.txt" -e 'd}' | \
    sed -e "/@@@ABSTRACT@@@/{r ${HELP_DIR}/abstract.txt" -e 'd}' | \
    sed -e "/@@@SYNTAX@@@/{r ${HELP_DIR}/syntax.txt" -e 'd}' | \
    sed -e '/@@@SCA OPTIONS@@@/{r src/help/options.txt' -e 'd}' | \
    if [ -n "$PARENT" ] && [ -f "src/${PARENT}/help/options.txt" ]; then
        PARENT_UPPER=$(echo "$PARENT" | tr '[:lower:]' '[:upper:]')
        sed -e "/@@@${PARENT_UPPER} OPTIONS@@@/{r src/${PARENT}/help/options.txt" -e 'd}'
    else
        cat
    fi | \
    sed -e "/@@@OPTIONS@@@/{r ${HELP_DIR}/options.txt" -e 'd}' | \
    sed -e "/@@@FURTHER READ@@@/{r ${FURTHER_READ}" -e 'd}' | \
    # Remove any remaining unsubstituted placeholders
    sed '/@@@[A-Z_ ]*@@@/d' \
    > "$OUTPUT_FILE"
