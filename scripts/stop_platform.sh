#!/bin/bash
# =============================================================================
# PipeZone Platform Shutdown Script
# =============================================================================
# Gracefully stops all platform services
# =============================================================================

set -e

echo "========================================="
echo "🛑 PipeZone Platform - Stopping..."
echo "========================================="
echo ""

# Stop all services
echo "Stopping all services..."
docker-compose down

# Stop any user VS Code Server instances
for compose_file in docker-compose.*.yml; do
    if [ -f "$compose_file" ] && [ "$compose_file" != "docker-compose.yml" ]; then
        echo "Stopping services from $compose_file..."
        docker-compose -f docker-compose.yml -f "$compose_file" down
    fi
done

echo ""
echo "========================================="
echo "✅ PipeZone Platform Stopped"
echo "========================================="
echo ""
echo "To start again:"
echo "  ./scripts/start_platform.sh"
echo ""
echo "To remove all data (⚠️  WARNING - This deletes everything!):"
echo "  docker-compose down -v"
echo "  rm -rf data/"
echo ""
