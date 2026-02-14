# OpenClaw Docker 部署 🦞

通过 Docker Compose 一键部署 OpenClaw AI 助手，通过 copilot-api 代理访问 GitHub Copilot 模型。

## 架构

```
飞书/Web ──→ OpenClaw ──→ Bifrost ──→ copilot-api ──→ GitHub Copilot
                │                                      ├─ Claude Opus 4.6
                │                                      ├─ GPT-5.2
                │                                      ├─ Gemini 3 Pro
                │                                      ├─ Gemini 3 Flash
                │                                      └─ text-embedding-3-small
                │
                ├──→ Notion API（读写页面/数据库）
                └──→ GitHub（workspace 自动备份）
```

| 服务 | 作用 | 端口 |
|------|------|------|
| **openclaw** | AI 助手主体（飞书集成、网关） | 18789 |
| **bifrost** | 高性能 AI 模型网关（Go，<100µs 开销） | 8080 (内部) |
| **copilot-proxy** | copilot-api — GitHub Copilot API 代理 | 4141 (localhost) |

## 快速开始

### 1. 准备配置

```bash
cp .env.example .env
```

编辑 `.env` 填入必填项：

| 变量 | 必填 | 说明 | 获取方式 |
|------|------|------|----------|
| `COPILOT_PROXY_TOKEN` | ✅ | GitHub Copilot Token（copilot-api 认证） | `docker compose run --rm copilot-proxy /entrypoint.sh --auth` |
| `FEISHU_APP_ID` | ✅ | 飞书 App ID | [open.feishu.cn](https://open.feishu.cn) |
| `FEISHU_APP_SECRET` | ✅ | 飞书 App Secret | [open.feishu.cn](https://open.feishu.cn) |
| `OPENCLAW_GATEWAY_TOKEN` | 自动生成 | 控制台访问 Token | 32 位随机字符串 |
| `NOTION_API_KEY` | 可选 | Notion Integration API Key | [notion.so/my-integrations](https://notion.so/my-integrations) |
| `GITHUB_PAT` | 可选 | GitHub PAT（workspace 备份用） | [github.com/settings/tokens](https://github.com/settings/tokens) |
| `BRAVE_API_KEY` | 可选 | Brave Search API Key（web_search 工具） | [brave.com/search/api](https://brave.com/search/api/) |

### 2. 启动服务

```bash
docker compose up -d
```

首次启动会自动：
- 拉取所有镜像
- 创建 Docker 内部网络
- 构建 copilot-api 镜像

### 3. 配置 Copilot Token

copilot-api 需要通过设备授权码流程获取 GitHub Copilot Token（`ghu_` 前缀）：

```bash
# 运行 auth 流程获取 token
docker compose run --rm copilot-proxy /entrypoint.sh --auth

# 按提示在浏览器中完成 GitHub 设备授权
# 将生成的 token 填入 .env 的 COPILOT_PROXY_TOKEN
```

> ⚠️ Token 过期后需重新执行 auth 流程并更新 `.env` 中的 `COPILOT_PROXY_TOKEN`，然后重启 copilot-proxy 服务。

### 4. 配置飞书

在飞书开放平台配置：
- **事件订阅 URL**: `http://YOUR_SERVER_IP:18789/webhook/feishu`
- **所需权限**: `im:message`、`im:message.group_at_msg`、`im:message.p2p_msg`

### 5. 访问控制台

```bash
ssh -L 18789:127.0.0.1:18789 user@your-server
# 浏览器打开 http://localhost:18789?token=YOUR_GATEWAY_TOKEN
```

## 可用模型

| 模型名称 | 来源 | 用途 |
|----------|------|------|
| `claude-opus-4.6` | GitHub Copilot (copilot-api) | 主力模型 |
| `gpt-5.2` | GitHub Copilot (copilot-api) | 通用模型 |
| `gemini-3-pro-preview` | GitHub Copilot (copilot-api) | Google 旗舰模型 |
| `gemini-3-flash-preview` | GitHub Copilot (copilot-api) | Google 快速模型 |
| `text-embedding-3-small` | GitHub Copilot (copilot-api) | 向量检索（memory_search） |

Bifrost 网关使用 `copilot/<模型名>` 格式路由请求。模型配置在 `bifrost_config.json` 中管理，定义了 `copilot` 自定义 Provider 指向 copilot-api。

> 💡 所有模型均通过 copilot-api 代理访问 GitHub Copilot，无需额外配置 API Key。Bifrost 使用 `_` 作为 dummy key，copilot-api 内部管理 Copilot 认证。

## 第三方集成

### Notion

OpenClaw 通过 Notion API 读写你的 Notion 页面和数据库。

**配置步骤：**
1. 访问 [notion.so/my-integrations](https://notion.so/my-integrations) 创建 Integration
2. Capabilities 勾选：Read content、Update content、Insert content
3. 复制 API Key（`ntn_` 开头）填入 `.env` 的 `NOTION_API_KEY`
4. 在 Notion 中给目标页面/数据库授权：页面右上角 `⋯` → Connect to → 选择你的 Integration

> 💡 授权一个顶层页面，其下所有子页面和数据库都自动可访问。

### Workspace Git 备份

OpenClaw 每天自动将 workspace 提交并推送到 GitHub。

**配置步骤：**
1. 创建 GitHub repo（如 `openclaw-workspace`）
2. 生成 Fine-grained PAT，仅授权该 repo 的 Contents 读写权限
3. 填入 `.env` 的 `GITHUB_PAT`
4. `init-workspace.sh` 会在每次启动时自动更新 Git remote URL 中的 PAT

> ⚠️ PAT 过期后需更新 `.env` 并重启 OpenClaw 容器。

## 数据持久化

所有运行时数据通过 Docker volume 挂载到 `./data/` 目录：

```
data/
├── bifrost/         # Bifrost 网关数据（SQLite）
├── copilot-api/     # copilot-api 数据（GitHub token）
└── openclaw/        # ⭐ OpenClaw 核心数据
    ├── config/      # Gateway 配置
    └── workspace/   # Agent workspace（记忆、文件、Git 仓库）
```

**重启安全性：**
- ✅ Workspace（记忆、文件、cron 任务）→ 在 volume 内，重启不丢
- ✅ Gateway 配置 → 在 volume 内，重启不丢
- ✅ copilot-api 数据 → 在 volume 内，重启不丢
- ✅ Notion/Git 凭证 → 通过 `.env` 注入
- ⚠️ `.env` 文件本身 → 在宿主机上，需要自行备份

## 文件结构

```
.
├── docker-compose.yml     # 服务编排（3 个服务）
├── bifrost_config.json    # Bifrost 网关配置（copilot Provider）
├── .env.example           # 环境变量模板
├── .env                   # 实际配置（⚠️ 不入 Git，自行备份）
├── scripts/               # 工具脚本
├── .github/workflows/     # CI/CD 自动部署
├── .gitignore
└── data/                  # 持久化数据（不入 Git）
```

## 常用命令

```bash
# 查看所有服务状态
docker compose ps

# 查看日志
docker compose logs -f openclaw
docker compose logs -f bifrost

# 重启单个服务
docker compose restart openclaw

# 更新到最新镜像
docker compose pull && docker compose up -d

# 停止所有服务
docker compose down

# 查看 OpenClaw 可用模型
docker compose exec openclaw node dist/index.js models list --all
```

## CI/CD 自动部署

项目通过 **GitHub Actions + Self-hosted Runner** 实现自动部署：当 `docker-compose.yml`、`bifrost_config.json` 或 workflow 文件变更并合入 `main` 时，自动在服务器上执行 `docker compose up`。

### 架构

```
GitHub (push to main) ──→ GitHub Actions ──→ Self-hosted Runner (你的服务器)
                                                   │
                                                   ├─ git pull
                                                   ├─ docker compose pull
                                                   └─ docker compose up -d
```

### Self-hosted Runner 安装

```bash
# 1. 在 GitHub repo → Settings → Actions → Runners → New self-hosted runner
# 2. 按提示在服务器上安装
mkdir ~/actions-runner && cd ~/actions-runner
curl -o actions-runner-linux-x64-2.322.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.322.0/actions-runner-linux-x64-2.322.0.tar.gz
tar xzf ./actions-runner-linux-x64-2.322.0.tar.gz
./config.sh --url https://github.com/yzffvinz/claw-docker --token <YOUR_TOKEN>

# 3. 注册为系统服务（开机自启）
sudo ./svc.sh install
sudo ./svc.sh start
```

### Runner 管理

```bash
# 查看状态
sudo ./svc.sh status

# 查看日志
journalctl -u actions.runner.* -f

# 重启
sudo ./svc.sh stop && sudo ./svc.sh start
```

### 触发规则

只有以下文件变更才会触发部署（其他文件如 README、scripts 不会触发）：
- `docker-compose.yml`
- `bifrost_config.json`
- `.github/workflows/**`

### 分支保护

`main` 分支已配置 Ruleset：
- ✅ **Require PR before merging** — 所有变更必须通过 PR，不能直接 push
- ✅ **Block force pushes** — 禁止 force push
- ✅ **Restrict deletions** — 禁止删除 main 分支
- Required approvals: 1

### 工作流程

```bash
# 1. 创建分支
git checkout -b feat/your-change

# 2. 修改 + 提交
git add . && git commit -m "✨ your change"

# 3. 推送 + 创建 PR
git push -u origin feat/your-change
# 在 GitHub 上创建 PR → Review → Merge

# 4. 合入后自动部署（如果触发路径匹配）
```

## 更新流程

### 手动更新

```bash
git pull                          # 拉取最新配置
docker compose pull               # 拉取最新镜像
docker compose up -d              # 重启（workspace 数据不丢）
```

### 自动更新（推荐）

通过 PR 合入 main，GitHub Actions 自动完成上述步骤。

## 迁移到新服务器

```bash
# 在新服务器上
git clone https://github.com/yzffvinz/claw-docker.git
cd claw-docker
scp user@old-server:~/claw-docker/.env ./.env          # 迁移配置
scp -r user@old-server:~/claw-docker/data ./data       # 迁移数据
docker compose up -d                                    # 启动
```

## Troubleshooting

### copilot-api Token 过期

**症状**：模型调用报 401/403，日志显示 token invalid

```bash
# 1. 重新生成 Copilot Token
docker compose run --rm copilot-proxy /entrypoint.sh --auth

# 2. 更新 .env 中的 COPILOT_PROXY_TOKEN

# 3. 重启 copilot-proxy
docker compose restart copilot-proxy
```

### OpenClaw memory_search 不工作

**症状**：`memory_search` 报错或返回空结果

```bash
# 检查 copilot-api embedding 是否可用
curl -s http://localhost:4141/v1/embeddings \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer _' \
  -d '{"model":"text-embedding-3-small","input":["test"]}' | head -c 200

# 检查 copilot-proxy 是否健康
docker compose ps copilot-proxy
```

### 飞书 Webhook 收不到消息

**症状**：飞书发消息没反应

```bash
# 1. 检查 OpenClaw 是否在运行
docker compose ps

# 2. 检查日志
docker compose logs -f openclaw | grep feishu

# 3. 确认飞书开放平台的事件订阅 URL 正确
# URL: http://YOUR_SERVER_IP:18789/webhook/feishu

# 4. 确认服务器防火墙开放了 18789 端口
```

### Docker 磁盘空间不足

**症状**：`df` 显示磁盘增长很快

```bash
# 查看 Docker 占用
docker system df

# 清理悬空镜像和构建缓存
docker system prune -f

# 清理停止的容器
docker container prune -f

# 查看日志文件大小（常见元凶）
du -sh /var/lib/docker/containers/*/*-json.log
```

### 新增环境变量后忘记更新 .env.example

**场景 1（开发者）**：改了 `docker-compose.yml` 加了新变量，但 `.env.example` 没同步

```bash
# 运行检查脚本
bash scripts/check-env-sync.sh

# 输出示例：
# ❌ docker-compose.yml 引用了 .env.example 中缺失的变量:
#   - NEW_VAR_NAME
# → 补上缺失的变量到 .env.example
```

**场景 2（使用者）**：更新代码后服务启动报错，可能是 `.env` 缺少新变量

```bash
# 对比你的 .env 和最新的 .env.example
diff <(grep -oP '^\w+(?==)' .env | sort) <(grep -oP '^\w+(?==)' .env.example | sort)

# 把 .env.example 中新增的变量补到你的 .env 里
```

### Git 备份 push 失败

**症状**：cron 日志报 push 错误

```bash
# 检查 PAT 是否过期
docker compose exec openclaw git -C /home/node/.openclaw/workspace remote -v

# 更新 PAT：修改 .env 中的 GITHUB_PAT，然后重启
docker compose restart openclaw
```

### 服务启动后立即退出

```bash
# 查看退出原因
docker compose logs openclaw | tail -50

# 常见原因：
# - .env 缺少必填变量 → 对照 .env.example 补全
# - 端口被占用 → lsof -i :18789
# - 数据目录权限问题 → chown -R 1000:1000 data/openclaw
```

## 安全说明

1. 端口仅绑定 `127.0.0.1`（除飞书 webhook 端口），通过 SSH 隧道访问
2. `.env` 已被 `.gitignore` 排除，敏感信息不会提交
3. 服务间通过 Docker 内部网络通信，不经过宿主机
4. Copilot Token 通过 `.env` 的 `COPILOT_PROXY_TOKEN` 变量注入，copilot-api 内部管理 Copilot 认证
5. Bifrost 网关不对外暴露端口，仅服务内部使用，auth 已关闭
6. Notion/GitHub PAT 建议使用最小权限原则
