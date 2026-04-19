#!/usr/bin/env bash
set -euo pipefail

for ns in sales zhku smart-home finance data monitoring ci-cd; do
    kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: security-admin
rules:
  - apiGroups: [""]
    resources: ["secrets", "serviceaccounts"]
    verbs: ["*"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs: ["*"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies"]
    verbs: ["*"]
  - apiGroups: ["policy"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["admissionregistration.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["audit.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["pods", "pods/log", "events", "namespaces"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-operator
rules:
  - apiGroups: [""]
    resources: ["namespaces", "nodes", "nodes/status", "persistentvolumes", "resourcequotas", "limitranges"]
    verbs: ["*"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["networkpolicies", "ingressclasses"]
    verbs: ["*"]
  - apiGroups: ["policy"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["scheduling.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["admissionregistration.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "nodes", "namespaces",
                "persistentvolumes", "persistentvolumeclaims", "events",
                "pods/log", "replicationcontrollers", "serviceaccounts"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps", "batch", "autoscaling", "networking.k8s.io",
                "storage.k8s.io", "policy", "scheduling.k8s.io"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-devops
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-developer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "persistentvolumeclaims",
                "events", "pods/log", "pods/exec", "pods/portforward",
                "replicationcontrollers", "serviceaccounts"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-viewer
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "persistentvolumeclaims",
                "events", "pods/log", "replicationcontrollers", "serviceaccounts"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps", "batch", "autoscaling", "networking.k8s.io"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
EOF

echo "ClusterRoles и namespaces созданы."
kubectl get clusterroles | grep -E 'security-admin|cluster-operator|cluster-viewer|namespace-'
