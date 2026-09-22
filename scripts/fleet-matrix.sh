#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================================"
echo "          FLEET MATRIX: TERRAFORM MODULE VERSIONS ACROSS ALL CLUSTERS          "
echo "================================================================================"
printf "%-15s %-25s %-20s %-12s\n" "ENVIRONMENT" "CLUSTER / COMPONENT" "MODULE" "PINNED VERSION"
echo "--------------------------------------------------------------------------------"

find "$REPO_ROOT/terragrunt/deployments" -name "terragrunt.hcl" | sort | while read -r file; do
  # Extract relative deployment path
  rel_path="${file#$REPO_ROOT/terragrunt/deployments/}"
  env=$(echo "$rel_path" | cut -d'/' -f1)
  cluster=$(echo "$rel_path" | cut -d'/' -f2)
  component=$(echo "$rel_path" | cut -d'/' -f3)

  # Parse module source line
  source_line=$(grep "source.*git::" "$file" 2>/dev/null || true)

  if [ -n "$source_line" ]; then
    module_name=$(echo "$source_line" | sed -n 's/.*terraform-modules\/parts\/\([a-zA-Z0-9_\/-]*\)?ref=.*/\1/p')
    pinned_version=$(echo "$source_line" | sed -n 's/.*ref=modules\/[a-zA-Z0-9_-]*-v\([0-9.]*\).*/v\1/p')

    if [ -z "$pinned_version" ]; then
      pinned_version=$(echo "$source_line" | sed -n 's/.*ref=\([^"]*\).*/\1/p')
    fi
  else
    module_name="local / unknown"
    pinned_version="unpinned"
  fi

  printf "%-15s %-25s %-20s %-12s\n" "$env" "$cluster ($component)" "$module_name" "$pinned_version"
done

echo "================================================================================"
