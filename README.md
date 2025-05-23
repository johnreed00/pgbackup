# PostgreSQL database backup

## Краткое описание

Цель: создание бэкапов баз данных PostgreSQL с проверкой целостности.

Ansible-playbook доставляет на целевую машину скрипт pgbackup.sh,
который запускает резервное копирование СУБД PostgreSQL согласно алгоритму:

1. Определяется список баз данных;<br>
2. Для каждой базы создается дамп штатными средствами;<br>
3. После создания все дампы помещаются в общий gzip-архив;<br>
4. Архив тестируется на целостность;<br>
5. Архив переносится в каталог /backups;

## Логирование

Скрипт использует логирование.
Успешный либо неуспешный результат каждого действия скрипта логируется с использованием syslog (facility.level: user.info, tag: pgbackup).

## Обработка нештатных ситуаций

Сообщение о возникновении нештатной ситуации или ошибки появляется в логах.
После возникновения ошибки не выполняются дальнейшие действия, кроме логирования.
Например, не создается архив, если перед этим не смогли корректно выполниться дампы. 

Примеры нештатных ситуаций:

- неправильный пароль от базы,<br>
- создание дампа завершилось ошибкой,<br>
- закончилось свободное место на одном из дисков,<br>
- тестирование архива завершилось неудачей и т.д.

Используется также механизм блокировок flock для синхронизации доступа. Например, может возникнуть ситуация,
когда запускается скрипт, но предыдущее выполнение скрипта не завершилось по каким-то причинам.
В этом случае новый запуск скрипта завершается с ошибкой для дальнейшего расследования.

## Состояние после работы скрипта

При любом сценарии отработки, по окончании работы скрипта на диске не должно оставаться никакого мусора: дампов БД, временных файлов и т.д. 
В каталоге /backups в итоге должны лежать только исправные бэкапы.

## Prerequisites

Плейбук/скрипт тестировались на платформе Debian GNU/Linux 12 (bookworm).<br>
Для успешной работы плейбука/скрипта необходимы следующие пакеты:

- postgresql-client-15<br>
- ansible-core<br>
- ansible<br>
- tar<br>
- gzip<br>
- bash<br>
- rsyslog (или другой демон syslog)

## Запуск плейбука

Добавляем переменные в host_vars. Секреты рекомендуем хранить в отдельном хранилище секретов (или шифровать с помощью ansible-vault).

Пример.
```
$ cat inventories/dev/host_vars/vm1.its.tech.yaml
pgbackup_dir: /backups
pgbackup_dbs: [ 'bm', 'companies', 'crm' ]
pgbackup_host: 127.0.0.1
pgbackup_user: postgres
pgbackup_vault_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
```
Запускаем плейбук. Пример.
```
$ ansible-playbook -i inventories/dev -l vm1.its.tech playbooks/pgbackup.yml
```
## Как запустить скрипт без плейбука

Необходимо зайти на целевую машину с бэкапами.<br>
Установить переменные окружения:

`PGBACKUP_DIR` - каталог бэкапов<br>
`PGBACKUP_DATABASES` - список баз данных (разделитель - пробел)<br>
`PGPASSWORD`, `PGUSER`, `PGHOST` - параметры соединения с БД<br>

Пример.
```
$ export PGBACKUP_DIR=/backups
$ export PGBACKUP_DATABASES='test0 test1 test2' # databases to backup
$ export PGPASSWORD=xxx # db connection
$ export PGUSER=postgres # db connection
$ export PGHOST=127.0.0.1 # db connection
```
Запускаем скрипт
```
$ flock -n /tmp/pgbackup.lock --command ./pgbackup.sh
```
