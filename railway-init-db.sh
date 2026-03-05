#!/bin/bash
# Railway 数据库初始化脚本（在容器内执行）
# 使用前请先执行: railway login 和 railway link（选择 taiga-back）

set -e
echo "=== 1. 执行 migrate ==="
railway ssh --service taiga-back -- python manage.py migrate

echo ""
echo "=== 2. 创建超级用户（按提示输入用户名、邮箱、密码）==="
railway ssh --service taiga-back -- python manage.py createsuperuser

echo ""
echo "=== 3. 收集静态文件 ==="
railway ssh --service taiga-back -- python manage.py collectstatic --noinput

echo ""
echo "=== 完成！请到 taiga-back 和 taiga-async 的 Variables 中更新 TAIGA_SITES_DOMAIN 为 gateway 的域名 ==="
