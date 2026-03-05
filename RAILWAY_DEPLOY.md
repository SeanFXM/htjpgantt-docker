# Hotone Japan 后端部署到 Railway

本指南将 **taiga-back** 及相关服务部署到 Railway，与已部署的前端对接。

## 架构概览

```
[用户] → [gateway] → 前端静态 / API / Events
              ↓
    taiga-back ← PostgreSQL
    taiga-events ← RabbitMQ
    taiga-async ← RabbitMQ
    taiga-protected
```

- **gateway**：统一入口，提供前端并代理到后端
- **taiga-back**：Django API
- **taiga-events**：WebSocket
- **taiga-async**：Celery 异步任务
- **taiga-protected**：附件服务

---

## 一、前置条件

1. 前端已部署：`htjpgantt-front` 在 Railway 上可访问
2. 本仓库 `htjpgantt-docker` 已推送到 GitHub
3. Railway 账号：https://railway.app

---

## 二、新建 Railway 项目

1. 打开 https://railway.app → **New Project**
2. 选择 **Empty Project**

---

## 三、添加服务（按顺序）

### 1. PostgreSQL

- **+ New** → **Database** → **PostgreSQL**
- 创建后记下服务名（如 `Postgres`）
- 在 **Variables** 中可看到 `PGHOST`、`PGUSER`、`PGPASSWORD`、`PGDATABASE`

### 2. RabbitMQ（异步任务）

- **+ New** → **Docker Image**
- 镜像：`rabbitmq:3.8-management-alpine`
- 服务名改为：**taiga-async-rabbitmq**
- **Variables** 添加：
  ```
  RABBITMQ_ERLANG_COOKIE=your-random-cookie-here
  RABBITMQ_DEFAULT_USER=taiga
  RABBITMQ_DEFAULT_PASS=taiga
  RABBITMQ_DEFAULT_VHOST=taiga
  ```

### 3. RabbitMQ（Events）

- **+ New** → **Docker Image**
- 镜像：`rabbitmq:3.8-management-alpine`
- 服务名改为：**taiga-events-rabbitmq**
- **Variables** 添加（与上面相同）：
  ```
  RABBITMQ_ERLANG_COOKIE=your-random-cookie-here
  RABBITMQ_DEFAULT_USER=taiga
  RABBITMQ_DEFAULT_PASS=taiga
  RABBITMQ_DEFAULT_VHOST=taiga
  ```

### 4. taiga-back

- **+ New** → **Docker Image**
- 镜像：`taigaio/taiga-back:latest`
- 服务名：**taiga-back**
- **Settings** → **Networking** → 端口填 **8000**
- **Variables** 添加（按实际值替换）：

  ```
  POSTGRES_DB=<从 Postgres 的 PGDATABASE 复制，通常为 railway>
  POSTGRES_USER=<从 Postgres 的 PGUSER 复制>
  POSTGRES_PASSWORD=<从 Postgres 的 PGPASSWORD 复制>
  POSTGRES_HOST=<从 Postgres 的 PGHOST 复制，或 postgres.railway.internal>
  
  TAIGA_SECRET_KEY=<随机字符串，如 openssl rand -hex 32>
  TAIGA_SITES_SCHEME=https
  TAIGA_SITES_DOMAIN=<部署完成后填 gateway 的域名>
  TAIGA_SUBPATH=
  
  EMAIL_BACKEND=console
  ENABLE_TELEMETRY=False
  
  RABBITMQ_USER=taiga
  RABBITMQ_PASS=taiga
  RABBITMQ_HOST=taiga-async-rabbitmq.railway.internal
  ```

- 在 Postgres 服务中，**Variables** → **Connect** → 选择 taiga-back，可自动注入数据库变量

### 5. taiga-async

- **+ New** → **Docker Image**
- 镜像：`taigaio/taiga-back:latest`
- 服务名：**taiga-async**
- **Settings** → 添加 **Custom Start Command**：`/taiga-back/docker/async_entrypoint.sh`
- **Variables**：与 taiga-back 相同（可复制）

### 6. taiga-events

- **+ New** → **Docker Image**
- 镜像：`taigaio/taiga-events:latest`
- 服务名：**taiga-events**
- **Settings** → **Networking** → 端口填 **8888**
- **Variables**：
  ```
  RABBITMQ_USER=taiga
  RABBITMQ_PASS=taiga
  TAIGA_SECRET_KEY=<与 taiga-back 相同>
  ```

### 7. taiga-protected

- **+ New** → **Docker Image**
- 镜像：`taigaio/taiga-protected:latest`
- 服务名：**taiga-protected**
- **Settings** → **Networking** → 端口填 **8003**
- **Variables**：
  ```
  SECRET_KEY=<与 taiga-back 相同>
  MAX_AGE=360
  ```

### 8. gateway（统一入口）

- **+ New** → **GitHub Repo**
- 选择 **SeanFXM/htjpgantt-docker**（或你的 fork）
- **Settings** → **Build**：
  - Builder：**Dockerfile**
  - Dockerfile Path：`railway/Dockerfile.gateway`
  - Root Directory：留空
- **Settings** → **Networking** → 端口填 **80**
- **Variables**：无需额外变量
- 部署完成后，**Generate Domain** 生成公网域名

---

## 四、初始化数据库

1. 等 taiga-back 首次部署完成
2. 进入 taiga-back 服务 → **Deployments** → 最新部署 → **View Logs** 或 **Shell**
3. 在 Shell 中执行：
   ```bash
   python manage.py migrate
   python manage.py createsuperuser
   python manage.py collectstatic --noinput
   ```
4. 按提示创建管理员账号

---

## 五、更新 TAIGA_DOMAIN

1. 在 gateway 服务中 **Generate Domain**，得到如 `xxx.up.railway.app`
2. 在 **taiga-back** 和 **taiga-async** 的 Variables 中，将 `TAIGA_SITES_DOMAIN` 改为该域名
3. 重新部署 taiga-back 和 taiga-async

---

## 六、访问与验证

1. 打开 gateway 的域名
2. 应看到 Hotone Japan 登录页
3. 使用 `createsuperuser` 创建的账号登录

---

## 七、常见问题

### 1. taiga-back 连不上数据库

- 使用 Postgres 的 **private** 变量（如 `PGHOST`），不要用公网 `DATABASE_URL`
- 确认 `POSTGRES_HOST` 为 `postgres.railway.internal` 或 Postgres 服务的内部主机名

### 2. gateway 502

- 确认 taiga-back、taiga-events、taiga-protected 都已成功部署
- 服务名必须为：`taiga-back`、`taiga-events`、`taiga-protected`，以便 `xxx.railway.internal` 解析

### 3. 登录后空白或 API 报错

- 检查 `TAIGA_SITES_DOMAIN` 是否与 gateway 域名一致
- 确认已执行 `migrate` 和 `createsuperuser`
