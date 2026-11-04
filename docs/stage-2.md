# Этап 2. Образ PostgreSQL 15 + Patroni

## Что сделано

- Базовый образ `postgres:15-bookworm` содержит PostgreSQL 15 и его утилиты.
- Установлены `python3-venv`, сертификаты и диагностические утилиты: curl, nc, ping.
- В `/opt/patroni-venv` установлены Patroni 4.1.5 с поддержкой ZooKeeper (`kazoo`) и `psycopg2-binary` 2.9.10.
- Каталог окружения добавлен в PATH, включён немедленный вывод логов Python.
- Контейнер работает от пользователя `postgres`.
- Конечная стадия копирует `postgres0.yml` и `postgres1.yml` в корень образа, с владельцем postgres и правами 0600.
- `.dockerignore` ограничивает контекст сборки необходимыми файлами.

Системный `python3-psycopg2` не нужен: изолированное окружение использует свой `psycopg2-binary`. Версии прямых Python-зависимостей закреплены; базовый образ и транзитивные зависимости могут обновляться.

## Почему две стадии

В репозитории на момент выполнения есть только README и .gitignore. Конфигурации Patroni — результат этапа 3 другого участника. Без них обычная сборка завершится ошибкой COPY, это явная зависимость между этапами.

Стадия `patroni-base` позволяет отдельно собрать и проверить результат этапа 2. Стадия `cluster` добавляет настоящие конфигурации. Пустые конфигурации не подставляются.

## Проверка этапа 2

Открыть Docker Desktop, дождаться запуска Linux engine. В PowerShell перейти в корень репозитория и выполнить:

```powershell
docker version
docker build --target patroni-base -t lab03-postgres:stage2 .
```

Команда `docker version` должна показывать Client и Server. После успешной сборки:

```powershell
docker run --rm lab03-postgres:stage2 postgres --version
docker run --rm lab03-postgres:stage2 patroni --version
docker run --rm lab03-postgres:stage2 patronictl --help
docker run --rm lab03-postgres:stage2 id
docker run --rm lab03-postgres:stage2 python3 -c "import sys, psycopg2, kazoo; print(sys.prefix); print(psycopg2.__version__); print(kazoo.__version__)"
docker run --rm lab03-postgres:stage2 python3 -m pip check
```

Ожидается PostgreSQL 15.x, Patroni 4.1.5, пользователь postgres (не root), окружение `/opt/patroni-venv`, успешные импорты и `No broken requirements found`. Эти команды проверяют образ, но не запуск репликации или отказоустойчивость. Сохранить собственные скриншоты успешной сборки и вывода команд для отчёта.

## Передача участникам этапов 3 и 4

1. Положить `postgres0.yml` и `postgres1.yml` рядом с Dockerfile.
2. Использовать `bin_dir: /usr/lib/postgresql/15/bin`.
3. Имена узлов и connect_address должны соответствовать сервисам Compose; в методичке это `pg-master`, `pg-slave`, `zoo:2181`.
4. Для данных использовать отдельный именованный Docker volume для каждой ноды. Внутри volume конфигурации должны указывать свой `data_dir`. Bind mount с Windows может потребовать дополнительной настройки прав.
5. Пароли PostgreSQL задаются в конфигурации Patroni либо `PATRONI_*` переменных. Одних `POSTGRES_USER` / `POSTGRES_PASSWORD` недостаточно, когда инициализацией управляет Patroni.
6. Команды Compose: `command: patroni /postgres0.yml` и `command: patroni /postgres1.yml`. `entrypoint` переопределять не требуется: унаследованный entrypoint официального образа выполняет указанную команду.

После появления конфигураций:

```powershell
docker build -t localhost/postres:patroni .
docker run --rm localhost/postres:patroni sh -c 'test -r /postgres0.yml && test -r /postgres1.yml && id'
```

Имя `localhost/postres:patroni` сохранено из методички; это локальный тег, отправлять его в Docker Registry не требуется. После появления Compose:

```powershell
docker compose up -d --build
docker compose ps
docker compose logs --tail=100
```

Изменение YAML, копируемого в образ, требует пересборки. `docker compose restart` не пересобирает образ.

## Статус проверки

Участник проекта подтвердил успешную сборку и выполнение проверок этапа 2. Проверка сборки отмечена в README как выполненная. Запуск кластера, репликация и failover относятся к последующим этапам.

## Источники

- Задание lab03.pdf, часть 1, пункт 1.
- https://github.com/Yaroslav1810/lab03-ha-postgres-cluster-
- https://patroni.readthedocs.io/en/latest/installation.html
- https://hub.docker.com/_/postgres
