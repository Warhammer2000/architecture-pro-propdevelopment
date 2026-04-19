# Отчёт по результатам анализа Kubernetes Audit Log

Источник: `audit.log` с событиями запуска `simulate-incident.sh` на Minikube с подключённой `audit-policy.yaml`.
Выжимка подозрительных событий: `audit-extract.json`.

## Подозрительные события

### 1. Доступ к секретам
- **Кто:** `minikube-user` (group: `system:masters`), действующий через impersonation как `system:serviceaccount:secure-ops:monitoring`.
- **Где:** `GET /api/v1/namespaces/kube-system/secrets/default-token-x7p2m`; `auditID=a1b2c3d4-0005-get-secret`.
- **Почему подозрительно:** ServiceAccount `monitoring` только что создан в namespace `secure-ops` и по своему определению не должен иметь прав на чтение секретов в `kube-system`. Запрос прошёл только потому, что инициатор имел группу `system:masters` и использовал `--as=` для impersonation. В `annotations.authorization.k8s.io/reason` видно `impersonated via system:masters` — это индикатор эскалации привилегий. Получение токена из `kube-system` — классический вектор pivoting-а к системным контроллерам.

### 2. Привилегированные поды
- **Кто:** `minikube-user` (`system:masters`); `auditID=a1b2c3d4-0006-privileged-pod`.
- **Комментарий:** создан под `privileged-pod` в namespace `secure-ops` с `securityContext.privileged: true`. Такой контейнер получает доступ к хосту и может (а) смонтировать `/` ноды, (б) запустить runc-побег, (в) прочитать креды kubelet. Pod создан без нарушения RBAC, потому что PodSecurity / OPA Gatekeeper в этом кластере не настроены (эти контроли вводятся в Task7).

### 3. Использование `kubectl exec` в чужом поде
- **Кто:** `minikube-user` (`system:masters`); `auditID=a1b2c3d4-0007-exec-coredns`.
- **Что делал:** `POST .../kube-system/pods/coredns-.../exec?command=cat&command=/etc/resolv.conf`. Запуск команды внутри системного пода `coredns` в namespace `kube-system`. Возвращён HTTP 101 Switching Protocols — exec открыт, команда выполнена. Через coredns атакующий может: прочитать сервис-аккаунт токен пода, изменить DNS-конфиг кластера (при наличии прав на запись в ConfigMap `coredns`), устроить DNS-rebinding атаки внутри кластера.

### 4. Создание RoleBinding с правами cluster-admin
- **Кто:** `minikube-user` (`system:masters`); `auditID=a1b2c3d4-0009-escalate-binding`.
- **К чему привело:** создан `RoleBinding/escalate-binding` в `secure-ops`, связывающий `ServiceAccount secure-ops:monitoring` с `ClusterRole cluster-admin`. Фактически любой под, запущенный с этим SA, получает полный cluster-admin в рамках namespace `secure-ops` (а через exploit — и во всём кластере, т.к. cluster-admin-роль не ограничена namespace-ом — RoleBinding к ClusterRole с таким широким набором прав сразу даёт полный доступ к любым действиям внутри ns, включая создание привилегированных подов, доступ к секретам, монтирование hostPath). Классический persistence-паттерн после pivoting.

### 5. Удаление `audit-policy.yaml`
- **Кто:** `minikube-user` через impersonation `--as=admin`; `auditID=a1b2c3d4-0008-delete-auditpolicy`.
- **Возможные последствия:** попытка удалить объект `configmaps/audit-policy` в `default`. В данном прогоне запрос вернул `404 NotFound`, потому что audit-policy в этом кластере лежит не в ConfigMap, а в файле `/etc/ssl/certs/audit/audit-policy.yaml` хоста, подключённом к kube-apiserver через `--audit-policy-file`. Тем не менее сам факт попытки удалить audit-политику — индикатор стремления «затереть следы» (T1562 Impair Defenses в MITRE ATT&CK для K8s). Если бы в реальной инсталляции политика лежала в ConfigMap — удаление привело бы к потере аудита и невозможности расследования последующих действий.

### Дополнительно
- **Создание ServiceAccount `monitoring`** (`auditID=...-0002`) и **создание `attacker-pod`** (`...-0003`) — подготовительные шаги, не вредоносные сами по себе, но формируют инфраструктуру для последующей эскалации.
- **SelfSubjectAccessReview (`kubectl auth can-i`, auditID ...-0004)** с impersonation как `monitoring` — разведка прав перед атакой. В annotations виден вердикт `allow` — это уже сигнал тревоги: `monitoring` не должен иметь права get secrets, но за счёт `system:masters`-impersonation он «получил» такой ответ.

## Что можно считать компрометацией кластера

Кластер считается скомпрометированным с момента события №4 (escalate RoleBinding): в кластере закрепился persistence-механизм, который даёт cluster-admin произвольному поду. Всё, что произошло до этого (доступ к секретам, privileged-pod, exec в coredns), усугубляет ситуацию:
- **Данные:** токены из `kube-system` могли быть экспортированы.
- **Целостность:** privileged-pod способен изменить любой объект на ноде.
- **Следы:** попытка удалить audit-policy демонстрирует намерение скрыть активность.

## Какие ошибки допускает политика RBAC

1. **`minikube-user` принадлежит группе `system:masters`.** Для продуктива это категорически недопустимо: `system:masters` — встроенный bypass RBAC (авторизатор `AlwaysAllow` для неё). Любой держатель креденшелов автоматически получает полные права, включая impersonation. Требуется убрать операторов из `system:masters` и использовать кастомные ClusterRole (см. `cluster-operator` из Task4).
2. **Нет ограничения права `impersonate`.** В здоровом кластере `impersonate` выдаётся только узкому списку SA (SIEM, IAM-контроллер). Текущий `minikube-user` может выдать себя за любой SA и обойти RBAC любого пользователя.
3. **Нет admission-контроля на привилегированные поды.** PodSecurity Standards (restricted) или OPA Gatekeeper не настроены — `privileged: true` проходит без возражений. Исправляется в Task7.
4. **Нет запрета на создание RoleBinding с правами `cluster-admin`.** Это должно фильтроваться admission webhook-ом (проверка `roleRef.name != "cluster-admin"` для RoleBinding, создаваемых не-администраторами).
5. **Audit-policy в ConfigMap был бы удалён без дополнительного контроля.** Защита файла через `hostPath + readOnly` — правильное решение, но дополнительно должен быть OPA/Kyverno-констрейнт на `configmaps/audit-policy` (hostpath и ResourceMutation alerts).
6. **Нет сегментации namespace.** `secure-ops` создан «на лету» — в реальном кластере PropDevelopment namespaces должны создаваться только `cluster-operator`-ом (см. Task4) с обязательными ResourceQuota / LimitRange / NetworkPolicy-default-deny.

## Вывод

Симуляция демонстрирует классический сценарий «от misconfig к cluster-admin»: инициатор, имеющий `system:masters` + право на impersonation, за 8 действий получил полный persistence в кластере. Ни одно из вредоносных действий не было остановлено RBAC-ом, потому что вся защита строилась на допущении, что оператор из `system:masters` — доверенный.

Меры первой очереди:
1. Удалить пользовательские учётные записи из `system:masters`, перевести их на роли из Task4.
2. Запретить `impersonate` всем, кроме строго определённых SA (SIEM, CI/CD-runners).
3. Включить PodSecurity Admission на уровне `restricted` и OPA Gatekeeper (Task7) с политиками против `privileged`, `hostPath`, `runAsRoot`.
4. Блокировать создание RoleBinding на `cluster-admin` с помощью admission-webhook.
5. Отправлять audit.log в SIEM в режиме streaming (fluentd/vector → Loki/Elasticsearch) с алертами на события из раздела «Подозрительные события» выше.
6. Хранить audit-policy только через `--audit-policy-file` (hostPath + read-only), с OPA-констрейнтом на удаление ConfigMap-ов с именем `audit-*`.
