#!/bin/bash
# PostToolUse hook for Bash: clean up pdflatex artifacts from slides directories.
# Fires after every Bash tool call. If pdflatex was run, removes aux/log/nav/out/snm/toc/vrb files
# from the slides directory, keeping only .tex and .pdf.

set -euo pipefail

INPUT=$(cat)

# Only act if pdflatex was run
if ! echo "$INPUT" | grep -q "pdflatex"; then
    exit 0
fi

# Find all slides directories under cycles/ and clean them
if [ ! -d "$CLAUDE_PROJECT_DIR/cycles" ]; then
    exit 0
fi

find "$CLAUDE_PROJECT_DIR/cycles" -type d -name "slides" 2>/dev/null | while read -r SLIDES_DIR; do
    find "$SLIDES_DIR" -type f \( \
        -name "*.aux" -o \
        -name "*.log" -o \
        -name "*.nav" -o \
        -name "*.out" -o \
        -name "*.snm" -o \
        -name "*.toc" -o \
        -name "*.vrb" -o \
        -name "*.fdb_latexmk" -o \
        -name "*.fls" -o \
        -name "*.synctex.gz" \
    \) -delete 2>/dev/null
done

exit 0
