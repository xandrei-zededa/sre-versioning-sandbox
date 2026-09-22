#!/usr/bin/env bash
# Quick commit helper with interactive prompt
set -e

echo ""
echo "Select the type of change you are committing:"
echo "  1) feat   - A new feature or module addition"
echo "  2) fix    - A bug fix or syntax correction"
echo "  3) chore  - Maintenance, dependencies, or configuration"
echo "  4) docs   - Documentation updates only"
echo ""
read -p "Enter number (1-4) [default: 1]: " choice
choice=${choice:-1}

case "$choice" in
  1) TYPE="feat" ;;
  2) TYPE="fix" ;;
  3) TYPE="chore" ;;
  4) TYPE="docs" ;;
  *) TYPE="feat" ;;
esac

echo ""
read -p "Enter scope (optional, e.g. aws-eks, s3-bucket or press Enter): " scope
read -p "Enter short description: " desc

if [ -z "$desc" ]; then
  echo "❌ Error: Description cannot be empty!"
  exit 1
fi

if [ -n "$scope" ]; then
  MSG="$TYPE($scope): $desc"
else
  MSG="$TYPE: $desc"
fi

echo ""
echo ">>> Creating commit: \"$MSG\""
git commit -m "$MSG"
