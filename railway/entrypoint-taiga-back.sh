#!/usr/bin/env bash
# Railway 定制：绑定 [::]:8000 以支持 IPv6 内部网络
# 基于 taigaio/taiga-back 官方 entrypoint，仅修改 gunicorn --bind
set -euo pipefail

echo Executing pending migrations
python manage.py migrate

echo Load default templates
python manage.py loaddata initial_project_templates

echo Give permission to taiga:taiga after mounting volumes
chown -R taiga:taiga /taiga-back

echo Starting Taiga API...
exec gosu taiga gunicorn taiga.wsgi:application \
 --name taiga_api \
 --bind '[::]:8000' \
 --workers 3 \
 --worker-tmp-dir /dev/shm \
 --log-level=info \
 --access-logfile - \
 "$@"
