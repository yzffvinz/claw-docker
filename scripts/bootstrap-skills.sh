#!/bin/sh
set -eu

SKILLS="${OPENCLAW_BOOTSTRAP_SKILLS:-}"

if [ -z "$SKILLS" ]; then
  echo "[bootstrap-skills] OPENCLAW_BOOTSTRAP_SKILLS is empty, skipping"
  exit 0
fi

mkdir -p "$HOME/.agents/skills"

OLD_IFS="$IFS"
IFS=','
set -- $SKILLS
IFS="$OLD_IFS"

for raw in "$@"; do
  skill=$(printf '%s' "$raw" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [ -z "$skill" ] && continue
  name=$(printf '%s' "$skill" | sed 's#^.*/##; s#@# #; s# .*##')

  if [ -d "$HOME/.agents/skills/$name" ]; then
    echo "[bootstrap-skills] already installed: $skill ($name)"
    continue
  fi

  echo "[bootstrap-skills] installing: $skill"
  npx skills add "$skill" -g -y
  echo "[bootstrap-skills] installed: $skill"
done
