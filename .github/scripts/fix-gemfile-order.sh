#!/usr/bin/env bash
set -euo pipefail

GEMFILE="Gemfile"
TARGET='gem "kanagawa", path: "engines/kanagawa"'

# Check if the line exists at all
if ! grep -qF "$TARGET" "$GEMFILE"; then
  echo "Kanagawa gem line not found in Gemfile — skipping"
  exit 0
fi

# Get the last non-empty line
LAST_LINE=$(grep -v '^\s*$' "$GEMFILE" | tail -1)

if [ "$LAST_LINE" = "$TARGET" ]; then
  echo "Kanagawa gem is already the last line — no action needed"
  exit 0
fi

echo "Moving kanagawa gem to end of Gemfile..."

# Remove the line from its current position (preserve everything else)
grep -vF "$TARGET" "$GEMFILE" > "${GEMFILE}.tmp"

# Remove trailing blank lines and append our line
sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "${GEMFILE}.tmp" > "$GEMFILE"
echo "" >> "$GEMFILE"
echo "$TARGET" >> "$GEMFILE"
rm -f "${GEMFILE}.tmp"

# Commit the fix
git add "$GEMFILE"
if git diff --cached --quiet; then
  echo "No changes to commit"
else
  git commit -m "chore: move kanagawa gem to end of Gemfile"
  echo "Done — kanagawa gem moved to end of Gemfile"
fi
