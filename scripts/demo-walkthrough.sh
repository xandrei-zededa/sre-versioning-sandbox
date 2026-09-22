#!/usr/bin/env bash
set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================================================"
echo "          DEMO SCENARIO: SRE PLATFORM TERRAFORM MODULES VERSIONING              "
echo "================================================================================"
echo ""
echo "This script demonstrates the complete lifecycle without affecting cloud state."
echo ""

# 1. CI Testing of multiple modules
echo ">>> [STAGE 1] Running Fast Isolated Unit Tests on All 5 Modules..."
for mod in sandbox-test aws/aws_eks aws/irsa_role aws/s3-bucket aws/rds-postgres; do
  dir="$REPO_ROOT/terraform-modules/parts/$mod"
  echo "  --> Testing $mod via tofu test with mock_provider..."
  (cd "$dir" && tofu init -backend=false > /dev/null 2>&1 && tofu test | grep "Success!")
done
echo ">>> [STAGE 1 COMPLETED] All 5 modules verified locally in seconds!"
echo ""

# 2. Canary comparison Dev vs Prod
echo ">>> [STAGE 2] Demonstrating Blast Radius Isolation & Canary Rollout..."
echo "  Cluster: development/zedcloud-madmax -> Pinned to modules/aws-eks-v1.1.0"
echo "  Cluster: production/zedcloud-production -> Pinned to modules/aws-eks-v1.0.0"
echo ""

echo "  Evaluating Plan for PRODUCTION cluster (Pinned to stable v1.0.0)..."
(cd "$REPO_ROOT/terragrunt/deployments/production/zedcloud-production/cluster" && \
 terragrunt plan | grep -E "aws_eks_cluster|Plan:")

echo ""
echo "  Evaluating Plan for DEVELOPMENT cluster (Canary updated to v1.1.0 with Karpenter)..."
(cd "$REPO_ROOT/terragrunt/deployments/development/zedcloud-madmax/cluster" && \
 terragrunt plan | grep -E "aws_eks_cluster|karpenter|Plan:")

echo ""
echo "================================================================================"
echo "  DEMO SUCCESSFUL: Production is 100% isolated while Dev safely tests v1.1.0!    "
echo "================================================================================"
