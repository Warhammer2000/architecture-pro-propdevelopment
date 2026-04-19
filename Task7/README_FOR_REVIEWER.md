# Task7. PodSecurity Admission + OPA Gatekeeper

## Структура

```
Task7/
├── 01-create-namespace.yaml            # namespace audit-zone с PSA enforce=restricted
├── insecure-manifests/                 # манифесты с нарушениями (должны отклоняться)
│   ├── 01-privileged-pod.yaml          # privileged: true
│   ├── 02-hostpath-pod.yaml            # hostPath volume
│   └── 03-root-user-pod.yaml           # runAsUser: 0
├── secure-manifests/                   # исправленные манифесты (должны проходить)
│   ├── 01-secure.yaml                  # nginx-unprivileged (UID 101)
│   ├── 02-secure.yaml                  # distroless nonroot (UID 65532)
│   └── 03-secure.yaml                  # alpine (UID 1000)
├── gatekeeper/
│   ├── constraint-templates/
│   │   ├── privileged.yaml             # K8sDenyPrivileged — запрет privileged
│   │   ├── hostpath.yaml               # K8sDenyHostPath — запрет hostPath
│   │   └── runasnonroot.yaml           # K8sRequireRunAsNonRoot — runAsNonRoot + readOnlyRootFilesystem
│   └── constraints/                    # инстансы ограничений, применяемые к audit-zone
│       ├── privileged.yaml
│       ├── hostpath.yaml
│       └── runasnonroot.yaml
├── verify/
│   ├── verify-admission.sh             # применяет все манифесты и проверяет реакцию admission-а
│   └── validate-security.sh            # сверяет установленные контроли
├── audit-policy.yaml                   # Policy для записи событий Pod/Constraint в audit.log
└── README_FOR_REVIEWER.md
```

## Что проверяет решение

| Правило | PodSecurity (restricted) | OPA Gatekeeper |
|---|---|---|
| Запрет `privileged: true` | ✓ (встроен) | `K8sDenyPrivileged` |
| Запрет `hostPath` volumes | ✓ (restricted блокирует большинство volume types) | `K8sDenyHostPath` |
| `runAsNonRoot: true` | ✓ (требует в restricted) | `K8sRequireRunAsNonRoot` |
| `readOnlyRootFilesystem: true` | не требует (не входит в restricted) | добавляется в `K8sRequireRunAsNonRoot` |
| `allowPrivilegeEscalation: false` | ✓ | добавлен в `K8sDenyPrivileged` |

PodSecurity Admission отсекает базовые нарушения (они будут отклонены даже без Gatekeeper). OPA Gatekeeper дублирует их и расширяет правилом на `readOnlyRootFilesystem` (которое restricted сам по себе не требует, но для PropDevelopment — обязательное условие, чтобы закрыть контейнерные runtime-атаки типа «записал бинарник и запустил»).

## Порядок применения

```bash
kubectl apply -f 01-create-namespace.yaml

kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.15/deploy/gatekeeper.yaml
kubectl wait --for=condition=Available deployment --all -n gatekeeper-system --timeout=180s

kubectl apply -f gatekeeper/constraint-templates/
sleep 5
kubectl apply -f gatekeeper/constraints/

chmod +x verify/verify-admission.sh verify/validate-security.sh
./verify/verify-admission.sh
./verify/validate-security.sh
```

## Ожидаемый результат

- `insecure-manifests/*` → отклонение. В выводе `kubectl apply` будет `admission webhook "validation.gatekeeper.sh" denied the request` либо сообщение от PodSecurity Admission о несоответствии `restricted`.
- `secure-manifests/*` → под создаётся, переходит в `Running`.
- `kubectl get K8sDenyPrivileged ... -o yaml` → `status.totalViolations: 0` после очистки (либо `1..3` если оставить insecure-под в аудит-режиме).

## Связь с остальным проектом

- Namespace `audit-zone` здесь — демо. В рамках PropDevelopment аналогичные настройки (PSA=restricted + эти 3 констрейнта) применяются к `smart-home` из Task4 (высокая чувствительность, биометрия) и к `finance`.
- Audit-policy из этого Task дополняет политику Task6 — события создания подов и изменения Constraint-ов отдельно помечены как RequestResponse.
- Скрипты из Task4 (RBAC) определяют, кто вообще может применять эти манифесты; Task7 задаёт, *что именно* они могут деплоить.
