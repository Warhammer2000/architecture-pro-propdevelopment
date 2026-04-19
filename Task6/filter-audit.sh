#!/usr/bin/env bash
set -uo pipefail

LOG="${1:-audit.log}"
OUT="${2:-audit-extract.json}"

if [[ ! -f "$LOG" ]]; then
    echo "audit.log not found at $LOG" >&2
    echo "Usage: $0 <audit.log> [audit-extract.json]" >&2
    exit 1
fi

echo "[" > "$OUT"

first=1
append() {
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == "null" ]] && continue
        if [[ $first -eq 1 ]]; then
            first=0
        else
            echo "," >> "$OUT"
        fi
        echo "$line" >> "$OUT"
    done
}

echo "=== 1. Доступ к секретам (verb=get|list, resource=secrets) ==="
jc_secrets=$(jq -c 'select(.objectRef.resource=="secrets" and (.verb=="get" or .verb=="list"))' "$LOG")
echo "$jc_secrets" | tee >(append)
echo "$jc_secrets" | jq -r '"  \(.user.username) -> \(.objectRef.namespace)/\(.objectRef.name)  [\(.responseStatus.code)]"'
echo

echo "=== 2. Создание exec/attach/portforward в чужих подах ==="
jc_exec=$(jq -c 'select(.verb=="create" and (.objectRef.subresource=="exec" or .objectRef.subresource=="attach"))' "$LOG")
echo "$jc_exec" | tee >(append)
echo "$jc_exec" | jq -r '"  \(.user.username) exec -> \(.objectRef.namespace)/\(.objectRef.name)"'
echo

echo "=== 3. Привилегированные поды ==="
jc_priv=$(jq -c 'select(.objectRef.resource=="pods" and .verb=="create" and (.requestObject.spec.containers[]?.securityContext.privileged == true))' "$LOG")
echo "$jc_priv" | tee >(append)
echo "$jc_priv" | jq -r '"  \(.user.username) created privileged pod -> \(.objectRef.namespace)/\(.requestObject.metadata.name)"'
echo

echo "=== 4. Создание/изменение RoleBinding и ClusterRoleBinding ==="
jc_rb=$(jq -c 'select((.objectRef.resource=="rolebindings" or .objectRef.resource=="clusterrolebindings") and (.verb=="create" or .verb=="update" or .verb=="patch"))' "$LOG")
echo "$jc_rb" | tee >(append)
echo "$jc_rb" | jq -r '"  \(.user.username) \(.verb) \(.objectRef.resource) -> \(.objectRef.namespace)/\(.requestObject.metadata.name) roleRef=\(.requestObject.roleRef.name)"'
echo

echo "=== 5. Удаление / изменение audit-policy ==="
jc_audit=$(jq -c 'select((.objectRef.resource=="configmaps" or .objectRef.name | tostring | test("audit-policy"; "i")) and (.verb=="delete" or .verb=="update" or .verb=="patch"))' "$LOG")
echo "$jc_audit" | tee >(append)
grep -Ei '"name":.*audit-policy' "$LOG" | head -n 20
echo

echo "=== 6. Impersonation (as=...) ==="
jc_imp=$(jq -c 'select(.impersonatedUser != null)' "$LOG")
echo "$jc_imp" | tee >(append)
echo "$jc_imp" | jq -r '"  \(.user.username) impersonates \(.impersonatedUser.username) -> \(.verb) \(.objectRef.resource)/\(.objectRef.name)"'
echo

echo "]" >> "$OUT"

if command -v jq >/dev/null 2>&1 && [[ -s "$OUT" ]]; then
    jq '.' "$OUT" > "$OUT.tmp" && mv "$OUT.tmp" "$OUT"
fi

echo "Extract written to $OUT"
