# Task6. Аудит активности пользователей и обнаружение инцидентов

## Файлы

| Файл | Назначение |
|---|---|
| `audit-policy.yaml` | Политика аудита Kubernetes (RequestResponse для чувствительных ресурсов, Metadata для остального) |
| `setup-minikube.sh` | Поднимает Minikube с подключённой audit-policy и экспортом логов в `/var/log/audit.log` |
| `simulate-incident.sh` | Скрипт симуляции инцидента из условия задачи |
| `filter-audit.sh` | Bash + jq скрипт фильтрации подозрительных событий из audit.log |
| `audit-extract.json` | Выжимка подозрительных событий (после прогона симуляции) |
| `analysis.md` | Отчёт по шаблону задания |

## Порядок запуска

```bash
chmod +x setup-minikube.sh simulate-incident.sh filter-audit.sh

./setup-minikube.sh

chmod +x simulate-incident.sh
./simulate-incident.sh

minikube ssh -- sudo cat /var/log/audit.log > audit.log

./filter-audit.sh audit.log audit-extract.json
```

## Быстрые ручные проверки (согласно заданию)

```bash
jq 'select(.objectRef.resource=="secrets" and .verb=="get")' audit.log
jq 'select(.verb=="create" and .objectRef.subresource=="exec")' audit.log
jq 'select(.objectRef.resource=="pods" and .requestObject.spec.containers[]?.securityContext.privileged==true)' audit.log
grep -i 'audit-policy' audit.log
```
