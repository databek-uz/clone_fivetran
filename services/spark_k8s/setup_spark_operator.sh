#!/bin/bash
# =============================================================================
# Spark Operator Setup Script for Kubernetes
# =============================================================================
# This script sets up the Spark Operator on Kubernetes to enable
# running Spark applications in the cluster
# =============================================================================

set -e

echo "========================================="
echo "PipeZone - Spark Operator Setup"
echo "========================================="

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

# Check if Helm is available (optional, for Spark Operator installation)
if ! command -v helm &> /dev/null; then
    echo "Warning: helm is not installed, will use kubectl apply instead"
    USE_HELM=false
else
    USE_HELM=true
fi

# Create namespace
echo "Creating Spark namespace..."
kubectl apply -f namespace.yaml

# Create service accounts and RBAC
echo "Creating service accounts and RBAC..."
kubectl apply -f spark_operator/service_account.yaml

# Install Spark Operator
if [ "$USE_HELM" = true ]; then
    echo "Installing Spark Operator using Helm..."

    # Add Spark Operator Helm repository
    helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator
    helm repo update

    # Install Spark Operator
    helm upgrade --install spark-operator spark-operator/spark-operator \
        --namespace spark-jobs \
        --set sparkJobNamespace=spark-jobs \
        --set webhook.enable=true \
        --set webhook.port=8080

    echo "✓ Spark Operator installed via Helm"
else
    echo "Installing Spark Operator using kubectl..."

    # Apply Spark Operator CRDs and deployment
    kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/spark-on-k8s-operator/master/manifest/spark-operator-crds.yaml
    kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/spark-on-k8s-operator/master/manifest/spark-operator.yaml -n spark-jobs

    echo "✓ Spark Operator installed via kubectl"
fi

# Wait for Spark Operator to be ready
echo "Waiting for Spark Operator to be ready..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/spark-operator -n spark-jobs || true

# Verify installation
echo ""
echo "Verifying installation..."
kubectl get pods -n spark-jobs

echo ""
echo "========================================="
echo "Spark Operator Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Apply cluster configurations:"
echo "   kubectl apply -f cluster_configs/"
echo ""
echo "2. Test with a sample Spark job:"
echo "   kubectl apply -f templates/spark_application_template.yaml"
echo ""
echo "3. Check Spark jobs:"
echo "   kubectl get sparkapplications -n spark-jobs"
echo ""
