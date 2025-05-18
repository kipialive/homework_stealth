#!/bin/bash

echo "Port-forwarding Kubernetes service to localhost:8000..."
kubectl port-forward svc/test-api-service 8000:80 -n test-bitcoin-price &

# Save the port-forward PID to kill later
PF_PID=$!
sleep 3

echo "Testing /price endpoint:"
curl -s http://localhost:8000/price | jq

echo -e "\nTesting /metrics endpoint:"
curl -s http://localhost:8000/metrics | head -n 20

# Cleanup
echo -e "\nStopping port-forwarding"
kill $PF_PID