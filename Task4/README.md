# Task4. Ролевой доступ к Kubernetes

## Состав

| Файл | Назначение |
|---|---|
| `roles-table.md` | Таблица ролей, прав и групп пользователей (+ матрица group×namespace) |
| `create-users.sh` | Создание K8s-пользователей через CertificateSigningRequest |
| `create-roles.sh` | Namespace-ы доменов PropDevelopment и 6 ClusterRole-ов |
| `bind-roles.sh` | ClusterRoleBinding и RoleBinding для групп пользователей |

## Порядок запуска

```bash
minikube start
chmod +x create-users.sh create-roles.sh bind-roles.sh
./create-roles.sh
./bind-roles.sh
./create-users.sh
```

## Быстрая проверка

```bash
kubectl --context=alice-sales-dev-context create deployment nginx --image=nginx -n sales       # ok
kubectl --context=alice-sales-dev-context get secrets -n sales                                  # forbidden
kubectl --context=alice-sales-dev-context create deployment nginx --image=nginx -n finance      # forbidden

kubectl --context=bob-zhku-devops-context get secrets -n zhku                                   # ok
kubectl --context=bob-zhku-devops-context get secrets -n finance                                # forbidden

kubectl --context=carol-security-context get secrets -A                                         # ok
kubectl --context=carol-security-context create deployment nginx --image=nginx -n sales         # forbidden

kubectl --context=dave-platform-context create namespace test-ns                                # ok
kubectl --context=dave-platform-context get secrets -A                                          # forbidden
```
