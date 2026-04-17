# Pending GitHub issues

This folder holds prepared issue bodies that cannot yet be created on the repo because **Issues are currently disabled on `KanagawaIO/finance`**.

## How to create them

1. Enable Issues on the repo: **Settings → Features → Issues (toggle on)**, or via API (`gh repo edit KanagawaIO/finance --enable-issues`).
2. Create the `kanagawa` + `kanagawa:milestone-N` labels:
   ```bash
   gh label create kanagawa --color "0E86D4" --description "Kanagawa engine work"
   for n in 1 2 3 4 5 6 7 8 9 10; do
     gh label create "kanagawa:milestone-$n" --color "A3B18A" --description "Kanagawa milestone $n"
   done
   ```
3. Create the issues from the markdown files in this folder:
   ```bash
   cd engines/kanagawa/.github/issues-to-create
   for f in milestone-1-*.md; do
     title=$(head -1 "$f" | sed 's/^# //')
     body=$(tail -n +3 "$f")
     gh issue create --repo KanagawaIO/finance \
       --title "$title" \
       --body "$body" \
       --label "kanagawa" \
       --label "kanagawa:milestone-1"
   done
   ```
4. Once created, update `engines/kanagawa/README.md` Roadmap section to replace the `#1` / `#2` / `#3` / `#4` placeholders with real issue numbers (e.g. `KanagawaIO/finance#42`).

## Format

Each file is markdown. The **first line** is the issue title (`# <title>`). Everything after is the body.
