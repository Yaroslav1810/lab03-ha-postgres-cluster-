# Этап 3. Настройка Patroni и PostgreSQL

## Конфиги

Добавлены `postgres0.yml` и `postgres1.yml`, совместимые с dockerfile этапа 2. Обе ноды входят в кластер `my_cluster`,
используют namespace `/service/` и ZooKeeper `zoo:2181`.

| Настройка | Первая нода | Вторая нода |
| --- | --- | --- |
| Имя Patroni | postgresql0 | postgresql1 |
| REST API (connect_address) | pg-master:8008 | pg-slave:8008 |
| PostgreSQL (connect_address) | pg-master:5432 | pg-slave:5432 |
| data_dir | /var/lib/postgresql/data/postgresql0 | /var/lib/postgresql/data/postgresql1 |
| pgpass | /tmp/pgpass0 | /tmp/pgpass1 |

REST API слушает `0.0.0.0:8008`, PostgreSQL — `0.0.0.0:5432`.
Имена `pg-master` и `pg-slave` должны разрешаться в сети будущего Compose.
Название сервиса не закрепляет роль: лидером может стать любая нода.

## Инициализация и репликация

- `initdb` создаёт базу с UTF-8 и контрольными суммами данных.
- `ttl=30`, `loop_wait=10`, `retry_timeout=10`, выполнено ограничение
  `loop_wait + 2 * retry_timeout <= ttl`.
- Включены синхронный режим с одной репликой, replication slots и `pg_rewind`.
  `synchronous_mode_strict=false` позволяет Patroni разрешить запись без
  синхронной реплики, когда она недоступна, в этот период синхронной гарантии нет.
- `wal_level=replica`, `hot_standby=on`, по 10 WAL senders и replication slots,
  `wal_log_hints=on`. Вместо устаревшего `wal_keep_segments=8` из PDF задан
  поддерживаемый PostgreSQL 15 `wal_keep_size=128MB` (8 стандартных сегментов).
- Исправлена вложенность `use_slots` и `parameters` в примере PDF.
  Используется современное имя `primary_start_timeout` вместо `master_start_timeout`.
- WAL архивируется в `/tmp/wal_archive`, как в методичке. Этот локальный архив
  временный и не является резервной копией или общим архивом для восстановления.
- Watchdog отключён строкой `'off'`, чтобы YAML не преобразовал значение в boolean.

Patroni создаёт суперпользователя `postgres` с паролем `postgres` и пользователя
репликации `replicator` с паролем `rep-pass`. Это учебные пароли из методички.
Сетевые подключения в `postgresql.pg_hba` используют SCRAM-SHA-256,
`password_encryption` согласован с этим способом аутентификации.
Локальный Unix-сокет использует `trust` внутри контейнера.
Правила `pg_hba` находятся в секции `postgresql`, чтобы Patroni управлял ими на обеих нодах.

## Сборка и поверка

Создать Compose с сервисами `pg-master`, `pg-slave`, `zoo`. Для каждой ноды
подключить отдельный volume к `/var/lib/postgresql/data`. Команды запуска:

```yaml
# pg-master
command: patroni /postgres0.yml
# pg-slave
command: patroni /postgres1.yml
```

Patroni использует `data_dir` из YAML. Если в Compose указан `PGDATA`, для ясности
согласовать его с `data_dir` соответствующей ноды. Одни `POSTGRES_USER` и
`POSTGRES_PASSWORD` не заменяют настройки `postgresql.authentication`.

Полная сборка образа:

```bash
docker build -t localhost/postres:patroni .
```

Валидатор Patroni проверяет доступность ZooKeeper. Для отдельной проверки
конфигураций до появления Compose использован временный ZooKeeper 3.9
в отдельной сети, без публикации портов на хост:

```bash
docker network create lab03-stage3-validation
docker run -d --name lab03-stage3-zoo --network lab03-stage3-validation --network-alias zoo zookeeper:3.9
```

Дождаться успешного выполнения проверки порта:

```bash
docker run --rm --network lab03-stage3-validation localhost/postres:patroni nc -z -w 3 zoo 2181
```

Затем проверить обе конфигурации и удалить временные ресурсы:

```bash
docker run --rm --network lab03-stage3-validation localhost/postres:patroni patroni --validate-config /postgres0.yml --ignore-listen-port
docker run --rm --network lab03-stage3-validation localhost/postres:patroni patroni --validate-config /postgres1.yml --ignore-listen-port
docker rm -fv lab03-stage3-zoo
docker network rm lab03-stage3-validation
```

Затем, после добавления Compose на этапе 4, проверить реальный запуск:

```bash
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 zoo pg-master pg-slave
docker compose exec pg-master patronictl -c /postgres0.yml list
```

Ожидается один лидер и одна реплика. Проверка репликации относится к этапу 5.
YAML копируются в образ: после их изменения нужна пересборка.
`bootstrap.dcs` применяется только при первой инициализации кластера,
для существующего кластера динамические параметры меняют через `patronictl edit-config`.

## вот это всё проверил у себя

| Проверка | Результат |
| --- | --- |
| Полная сборка Dockerfile, включая COPY двух YAML | Успешно |
| PostgreSQL в образе | 15.19 |
| Patroni в образе | 4.1.5 |
| Пользователь контейнера | postgres, uid=999 |
| `python3 -m pip check` | No broken requirements found. |
| Владелец и права обоих YAML в образе | postgres:postgres, 0600 |
| `patroni --validate-config /postgres0.yml --ignore-listen-port` в тестовой сети | Код завершения 0, ошибок нет |
| `patroni --validate-config /postgres1.yml --ignore-listen-port` в тестовой сети | Код завершения 0, ошибок нет |

Для проверки использовалась отдельная сеть с ZooKeeper. После открытия порта
2181 обе конфигурации прошли валидацию без ошибок. Тестовый контейнер и сеть
после проверки удалены.

На этом этапе проверены конфигурации и сборка образа. Запуск двух нод и
проверка репликации выполняются на этапах 4 и 5.