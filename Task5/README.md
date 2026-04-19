# Task5. Управление трафиком внутри кластера Kubernetes

## Файлы

| Файл | Назначение |
|---|---|
| `deploy-pods.sh` | Разворачивает 4 пода Nginx с метками `role` и создаёт Service для каждого |
| `non-admin-api-allow.yaml` | Набор сетевых политик: default-deny + разрешения для пары front/back и admin-front/admin-back |
| `verify.sh` | Проверяет, что разрешённые потоки работают, а запрещённые — отрезаны |

## Важно про CNI

Стандартный CNI Minikube (`kindnet`) **не применяет NetworkPolicy** — политики будут создаваться, но трафик всё равно будет ходить. Запускать кластер нужно с CNI, поддерживающим политики:

```bash
minikube delete
minikube start --cni=calico
```

Альтернативы: `--cni=cilium` либо вручную установить Calico после старта.

## Порядок применения

```bash
chmod +x deploy-pods.sh verify.sh
./deploy-pods.sh
kubectl apply -f non-admin-api-allow.yaml
./verify.sh
```

## Что проверяется

1. `front-end → back-end-api` — **разрешено** (пара UI ↔ API)
2. `admin-front-end → admin-back-end-api` — **разрешено** (пара админского UI ↔ админского API)
3. `front-end → admin-back-end-api` — **запрещено** (изоляция обычного UI от админского API)
4. `admin-front-end → back-end-api` — **запрещено** (админский UI не общается с обычным API)
5. `back-end-api → admin-back-end-api` — **запрещено**
6. Случайный под в том же namespace без нужных меток — **не имеет доступа ни к одному API**

## Применение к кейсу PropDevelopment

Паттерн «admin-API изолирован от обычного UI» напрямую лечит проблему кросс-доступа, описанную в кейсе:
- `admin-back-end-api` — аналог admin-API управляющих компаний / финансового контура;
- `admin-front-end` — панель администраторов УК / операторов;
- `back-end-api` + `front-end` — пользовательский контур (собственник, клиент).

Таким образом, даже при компрометации обычного пользовательского фронта злоумышленник не может обратиться к административному API — срабатывает default-deny + отсутствие разрешения в политике.
