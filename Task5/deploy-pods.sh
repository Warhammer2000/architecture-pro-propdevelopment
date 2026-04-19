#!/usr/bin/env bash
set -euo pipefail

kubectl run front-end-app        --image=nginx --labels role=front-end        --expose --port 80
kubectl run back-end-api-app     --image=nginx --labels role=back-end-api     --expose --port 80
kubectl run admin-front-end-app  --image=nginx --labels role=admin-front-end  --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80

kubectl wait --for=condition=Ready pod -l 'role in (front-end,back-end-api,admin-front-end,admin-back-end-api)' --timeout=120s

kubectl get pods -o wide --show-labels
kubectl get svc
