#!/usr/bin/env bash
set -euo pipefail

AUDIT_DIR="$(pwd)/minikube-mount"
mkdir -p "$AUDIT_DIR"
cp audit-policy.yaml "$AUDIT_DIR/audit-policy.yaml"

minikube delete || true

minikube start \
    --mount=true \
    --mount-string="$AUDIT_DIR:/etc/ssl/certs/audit" \
    --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit/audit-policy.yaml \
    --extra-config=apiserver.audit-log-path=/var/log/audit.log \
    --extra-config=apiserver.audit-log-maxage=7 \
    --extra-config=apiserver.audit-log-maxbackup=2 \
    --extra-config=apiserver.audit-log-maxsize=100

echo
echo "Проверка, что apiserver поднялся с аудитом:"
minikube ssh -- "sudo grep audit-policy /etc/kubernetes/manifests/kube-apiserver.yaml"

echo
echo "Выгрузить audit.log:"
echo "  minikube ssh -- sudo cat /var/log/audit.log > audit.log"
