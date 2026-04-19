#!/usr/bin/env bash
set -uo pipefail

probe() {
    local src_label="$1"
    local target_svc="$2"
    local expected="$3"

    local pod
    pod=$(kubectl get pod -l "role=${src_label}" -o jsonpath='{.items[0].metadata.name}')

    local result
    result=$(kubectl exec "$pod" -- sh -c "wget -qO- --timeout=3 http://${target_svc} >/dev/null 2>&1 && echo OK || echo FAIL")

    printf "%-22s -> %-22s expected=%-4s got=%s\n" "$src_label" "$target_svc" "$expected" "$result"
}

echo "Ожидаемые результаты по политикам:"
probe "front-end"        "back-end-api-app"       "OK"
probe "admin-front-end"  "admin-back-end-api-app" "OK"
probe "front-end"        "admin-back-end-api-app" "FAIL"
probe "admin-front-end"  "back-end-api-app"       "FAIL"
probe "back-end-api"     "admin-back-end-api-app" "FAIL"

echo
echo "Проверка из случайного alpine-пода (не должен иметь доступа ни к одному API):"
kubectl run test-random-$RANDOM --rm -i --restart=Never --image=alpine --labels role=outsider -- \
    sh -c 'wget -qO- --timeout=3 http://back-end-api-app >/dev/null 2>&1 && echo BAD-OK || echo EXPECTED-FAIL;
           wget -qO- --timeout=3 http://admin-back-end-api-app >/dev/null 2>&1 && echo BAD-OK || echo EXPECTED-FAIL'
