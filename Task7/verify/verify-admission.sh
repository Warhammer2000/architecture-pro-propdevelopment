#!/usr/bin/env bash
set -uo pipefail

expect_rejected() {
    local manifest="$1"
    echo
    echo "----- apply $manifest (ожидается REJECTED) -----"
    output=$(kubectl apply -f "$manifest" 2>&1)
    rc=$?
    echo "$output"
    if [[ $rc -ne 0 ]]; then
        echo "OK: манифест отклонён admission-контроллером"
    else
        echo "FAIL: манифест ПРИНЯТ — политика не работает"
        kubectl delete -f "$manifest" --ignore-not-found
        return 1
    fi
}

expect_accepted() {
    local manifest="$1"
    echo
    echo "----- apply $manifest (ожидается ACCEPTED) -----"
    output=$(kubectl apply -f "$manifest" 2>&1)
    rc=$?
    echo "$output"
    if [[ $rc -eq 0 ]]; then
        echo "OK: безопасный манифест принят"
        kubectl delete -f "$manifest" --ignore-not-found
    else
        echo "FAIL: безопасный манифест отклонён"
        return 1
    fi
}

echo "===== INSECURE MANIFESTS (должны быть отклонены) ====="
expect_rejected insecure-manifests/01-privileged-pod.yaml
expect_rejected insecure-manifests/02-hostpath-pod.yaml
expect_rejected insecure-manifests/03-root-user-pod.yaml

echo
echo "===== SECURE MANIFESTS (должны проходить) ====="
expect_accepted secure-manifests/01-secure.yaml
expect_accepted secure-manifests/02-secure.yaml
expect_accepted secure-manifests/03-secure.yaml
