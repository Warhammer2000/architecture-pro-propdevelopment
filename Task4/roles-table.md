# Ролевая модель Kubernetes для PropDevelopment

## Обоснование модели

Модель построена от организационной структуры PropDevelopment (4 домена + служебные команды) и требований задания:
- выделена привилегированная роль для ИБ (просмотр секретов, RBAC, audit-policy);
- выделена роль настройки кластера (cluster-operator);
- выделена роль только на чтение (cluster-viewer);
- внутри каждого домена — три уровня: devops (полный доступ в namespace, включая секреты), developer (деплой без секретов), viewer (read-only).

Namespaces соответствуют доменам:
- `sales` — домен «Продажи»
- `zhku` — домен «ЖКУ»
- `smart-home` — интеграция Умного дома из Task3 (выделен отдельно из-за биометрии и повышенных требований ИБ)
- `finance` — домен «Финансы»
- `data` — домен «Данные»
- служебные `kube-system`, `monitoring`, `ci-cd` — доступ только у security-admins и platform-operators.

## Таблица ролей

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| **security-admin** (ClusterRole) | Полный доступ к `secrets`, `serviceaccounts`, `rbac.authorization.k8s.io/*`, `networkpolicies`, `audit.k8s.io`, admission webhooks. Read-only на `pods`, `events`, `pods/log` во всех namespace для расследования инцидентов. | Специалисты по ИБ (`security-admins`) |
| **cluster-operator** (ClusterRole) | Управление `namespaces`, `nodes`, `persistentvolumes`, `storageclasses`, `networkpolicies`, `ingressclasses`, `policy/*`, `scheduling.k8s.io`, `admissionregistration.k8s.io`. Read-only на остальные ресурсы. Не имеет прямого доступа к `secrets`. | Platform / SRE-инженеры (`platform-operators`) |
| **cluster-viewer** (ClusterRole) | `get`, `list`, `watch` на все не-чувствительные ресурсы во всех namespace: pods, services, configmaps, deployments, networkpolicies, events, logs. **Не имеет доступа к `secrets`.** | Аудиторы, руководители операционных команд, менеджеры (`auditors`) |
| **namespace-devops** (ClusterRole + RoleBinding на нужный ns) | Полный доступ ко всем ресурсам внутри своего namespace, включая `secrets` и `rolebindings` в рамках этого ns. | DevOps-инженеры каждой продуктовой команды: `sales-devops`, `zhku-devops`, `finance-devops`, `data-devops` |
| **namespace-developer** (ClusterRole + RoleBinding на нужный ns) | Деплой и управление рабочими нагрузками в своём namespace: `pods`, `services`, `configmaps`, `deployments`, `statefulsets`, `jobs`, `ingresses`, `hpa`, `pvc`, `pods/log`, `pods/exec`. **Не имеет доступа к `secrets`** (шифрованные параметры получаются через SealedSecrets / Vault или через namespace-devops). | Разработчики продуктовых команд: `sales-developers`, `zhku-developers`, `finance-developers`, `data-developers` |
| **namespace-viewer** (ClusterRole + RoleBinding на нужный ns) | `get`, `list`, `watch` на все ресурсы своего namespace, кроме `secrets`. | Бизнес-аналитики, владельцы продуктов, менеджеры операционных команд: `*-viewers` |

## Матрица «группа → namespace → роль»

| Группа | sales | zhku | smart-home | finance | data | kube-system | monitoring | ci-cd |
|---|---|---|---|---|---|---|---|---|
| security-admins | security-admin (cluster-wide) | | | | | ✓ | ✓ | ✓ |
| platform-operators | cluster-operator (cluster-wide) | | | | | ✓ | ✓ | ✓ |
| auditors | cluster-viewer (cluster-wide, без secrets) | | | | | ✓ (без secrets) | ✓ | ✓ |
| sales-devops | devops | — | — | — | — | — | — | — |
| sales-developers | developer | — | — | — | — | — | — | — |
| sales-viewers | viewer | — | — | — | — | — | — | — |
| zhku-devops | — | devops | devops | — | — | — | — | — |
| zhku-developers | — | developer | developer (с ограничением — без доступа к секретам биометрии) | — | — | — | — | — |
| zhku-viewers | — | viewer | viewer | — | — | — | — | — |
| finance-devops | — | — | — | devops | — | — | — | — |
| finance-developers | — | — | — | developer | — | — | — | — |
| finance-viewers | — | — | — | viewer | — | — | — | — |
| data-devops | — | — | — | — | devops | — | — | — |
| data-developers | — | — | — | — | developer | — | — | — |
| data-viewers | — | — | — | — | viewer | — | — | — |

## Тестовые пользователи

Для проверки ролевой модели создаются 4 учётные записи (K8s client certificates):

| Пользователь | Группа (`O` в сертификате) | Ожидаемая роль |
|---|---|---|
| `alice-sales-dev` | `sales-developers` | namespace-developer в `sales` |
| `bob-zhku-devops` | `zhku-devops` | namespace-devops в `zhku` и `smart-home` |
| `carol-security` | `security-admins` | security-admin (cluster-wide) |
| `dave-platform` | `platform-operators` | cluster-operator (cluster-wide) |
