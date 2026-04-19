#!/usr/bin/env bash
set -uo pipefail

echo "===== Проверка PodSecurity Admission на namespace ====="
kubectl get ns audit-zone -o jsonpath='{.metadata.labels}' | tr ',' '\n' | grep pod-security
echo

echo "===== Установленные ConstraintTemplates ====="
kubectl get constrainttemplates -o custom-columns=NAME:.metadata.name,CRD:.spec.crd.spec.names.kind

echo
echo "===== Установленные Constraints и нарушения ====="
for kind in K8sDenyPrivileged K8sDenyHostPath K8sRequireRunAsNonRoot; do
    echo
    echo "--- $kind ---"
    kubectl get "$kind" -o custom-columns=NAME:.metadata.name,ENFORCEMENT:.spec.enforcementAction,MATCH:.spec.match.namespaces
    kubectl get "$kind" -o jsonpath='{range .items[*]}  total-violations: {.status.totalViolations}{"\n"}{end}'
done

echo
echo "===== Поды в namespace audit-zone ====="
kubectl get pods -n audit-zone -o wide

echo
echo "===== Gatekeeper controller ====="
kubectl get pods -n gatekeeper-system
