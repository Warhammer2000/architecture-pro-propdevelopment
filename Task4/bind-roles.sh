#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f - <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: security-admin-binding
subjects:
  - kind: Group
    name: security-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: security-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-operator-binding
subjects:
  - kind: Group
    name: platform-operators
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-viewer-binding
subjects:
  - kind: Group
    name: auditors
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: cluster-viewer
  apiGroup: rbac.authorization.k8s.io
EOF

for ns in sales zhku smart-home finance data; do
    domain="${ns}"
    case "$ns" in
        smart-home) domain="zhku" ;;
    esac

    kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ns}-devops-binding
  namespace: ${ns}
subjects:
  - kind: Group
    name: ${domain}-devops
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-devops
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ns}-developer-binding
  namespace: ${ns}
subjects:
  - kind: Group
    name: ${domain}-developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-developer
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${ns}-viewer-binding
  namespace: ${ns}
subjects:
  - kind: Group
    name: ${domain}-viewers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
done

echo
echo "Проверка прав доступа:"
kubectl auth can-i get secrets --as=system:anonymous --as-group=security-admins -n zhku
kubectl auth can-i get secrets --as=system:anonymous --as-group=sales-developers -n sales
kubectl auth can-i create deployments --as=system:anonymous --as-group=sales-developers -n sales
kubectl auth can-i create deployments --as=system:anonymous --as-group=sales-developers -n zhku
kubectl auth can-i get nodes --as=system:anonymous --as-group=platform-operators
kubectl auth can-i list pods --as=system:anonymous --as-group=auditors -A
