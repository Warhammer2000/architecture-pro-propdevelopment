#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-minikube}"
WORK_DIR="${WORK_DIR:-./users}"
mkdir -p "$WORK_DIR"

create_user() {
    local user="$1"
    local group="$2"
    local dir="$WORK_DIR/$user"
    mkdir -p "$dir"

    openssl genrsa -out "$dir/$user.key" 2048
    openssl req -new -key "$dir/$user.key" -out "$dir/$user.csr" \
        -subj "/CN=$user/O=$group"

    local csr_b64
    csr_b64=$(base64 -w 0 < "$dir/$user.csr" 2>/dev/null || base64 < "$dir/$user.csr" | tr -d '\n')

    kubectl delete csr "$user" --ignore-not-found

    cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $user
spec:
  request: $csr_b64
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
  expirationSeconds: 31536000
EOF

    kubectl certificate approve "$user"

    for _ in $(seq 1 10); do
        local cert
        cert=$(kubectl get csr "$user" -o jsonpath='{.status.certificate}')
        if [[ -n "$cert" ]]; then
            echo "$cert" | base64 -d > "$dir/$user.crt"
            break
        fi
        sleep 1
    done

    kubectl config set-credentials "$user" \
        --client-certificate="$dir/$user.crt" \
        --client-key="$dir/$user.key" \
        --embed-certs=true

    kubectl config set-context "$user-context" \
        --cluster="$CLUSTER_NAME" \
        --user="$user"

    echo "Created user $user (group=$group); context: $user-context"
}

create_user "alice-sales-dev"  "sales-developers"
create_user "bob-zhku-devops"  "zhku-devops"
create_user "carol-security"   "security-admins"
create_user "dave-platform"    "platform-operators"

echo
echo "Доступные контексты:"
kubectl config get-contexts
