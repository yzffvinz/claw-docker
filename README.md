# OpenClaw Docker 部署 🦞

通过 Docker Compose 一键部署 OpenClaw AI 助手，集成 Azure OpenAI 和 GitHub Copilot 模型。

## 架构

```
飞书/Web ──→ OpenClaw ──→ LiteLLM ──→ Azure OpenAI (GPT 5.2)
                │            │
                │            ├──→ Copilot Proxy ──→ GitHub Copilot
                │            │                      ├─ Claude Opus 4.6
                │            │                      ├─ Claude Opus 4.5
                │            │                      └─ Claude Sonnet 4.5
                │            │
                │            └──→ Embedding API (text-embedding-3-small)
                │
                ├──→ Notion API（读写页面/数据库）
                └──→ GitHub（workspace 自动备份）
```

| 服务 | 作用 | 端口 |
|------|------|------|
| **openclaw** | AI 助手主体（飞书集成、网关） | 18789 |
| **litellm** | 统一模型网关，多模型路由 | 4000 (内部) |
| **copilot-proxy** | GitHub Copilot API 代理 | 3001 (localhost) |
| **postgres** | LiteLLM 数据库 | 5432 (内部) |

## 快速开始

### 1. 准备配置

```bash
cp .env.example .env
```

编辑 `.env` 填入必填项：

| 变量 | 必填 | 说明 | 获取方式 |
|------|------|------|----------|
| `GITHUB_TOKEN` | ✅ | GitHub PAT（copilot-proxy 引导用） | [github.com/settings/tokens](https://github.com/settings/tokens) |
| `COPILOT_PROXY_TOKEN` | ✅ | OAuth token（首次部署后通过 Web UI 生成） | 见下方步骤 3 |
| `AZURE_OPENAI_API_KEY` | ✅ | Azure OpenAI 密钥 | Azure Portal |
| `AZURE_OPENAI_ENDPOINT` | ✅ | Azure OpenAI 端点 | Azure Portal |
| `AZURE_OPENAI_MODEL` | ✅ | Azure 模型名 | Azure Portal |
| `FEISHU_APP_ID` | ✅ | 飞书 App ID | [open.feishu.cn](https://open.feishu.cn) |
| `FEISHU_APP_SECRET` | ✅ | 飞书 App Secret | [open.feishu.cn](https://open.feishu.cn) |
| `NOTION_API_KEY` | 可选 | Notion Integration API Key | [notion.so/my-integrations](https://notion.so/my-integrations) |
| `GITHUB_PAT` | 可选 | GitHub PAT（workspace 备份用） | [github.com/settings/tokens](https://github.com/settings/tokens) |
| `EMBEDDING_API_BASE` | 可选 | Embedding 服务地址（OpenAI 兼容） | 自行部署 |
| `EMBEDDING_API_KEY` | 可选 | Embedding 服务 API Key | 自行部署 |

### 2. 启动服务

```bash
docker compose up -d
```

首次启动会自动：
- 拉取所有镜像
- 创建 Docker 内部网络
- 初始化 PostgreSQL 数据库
- 运行 `init-workspace.sh` 配置 OpenClaw 容器环境

### 3. 配置 Copilot Proxy Token

GitHub Copilot 需要通过 OAuth 流程获取 token：

```bash
# 本地建立 SSH 隧道
ssh -L 3001:127.0.0.1:3001 user@your-server

# 浏览器打开
http://localhost:3001
```

在 Web UI 中：**Generate Token** → **Set as Default** → 将 `ghu_xxx` 复制到 `.env` 的 `COPILOT_PROXY_TOKEN`。

```bash
# 重启 LiteLLM 使 token 生效
docker compose restart litellm
```

> ⚠️ `ghu_` token 有效期有限（约 30 分钟），过期后需重新生成。

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

| 模型名称 | 来源 | 上下文窗口 |
|----------|------|-----------|
| `openai/claude-opus-4-6` | GitHub Copilot | 200K |
| `openai/claude-opus-4-5` | GitHub Copilot | 200K |
| `openai/claude-sonnet-4-5` | GitHub Copilot | 200K |
| `openai/azure-gpt-5-2` | Azure OpenAI | 128K |
| `text-embedding-3-small` | 自行部署 | — |

默认模型：`openai/claude-opus-4-6`

> 💡 `text-embedding-3-small` 用于 OpenClaw 的 `memory_search` 语义向量检索，需在 `.env` 中配置 `EMBEDDING_API_BASE` 和 `EMBEDDING_API_KEY`。

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
├── postgres/        # LiteLLM 数据库
├── litellm/         # LiteLLM 运行时数据
├── copilot-proxy/   # Copilot OAuth token 存储
└── openclaw/        # ⭐ OpenClaw 核心数据
    ├── config/      # Gateway 配置
    └── workspace/   # Agent workspace（记忆、文件、Git 仓库）
```

**重启安全性：**
- ✅ Workspace（记忆、文件、cron 任务）→ 在 volume 内，重启不丢
- ✅ Gateway 配置 → 在 volume 内，重启不丢
- ✅ Notion/Git 凭证 → 通过 `.env` + `init-workspace.sh` 每次启动注入
- ⚠️ `.env` 文件本身 → 在宿主机上，需要自行备份

## 文件结构

```
.
├── docker-compose.yml     # 服务编排（4 个服务）
├── litellm_config.yaml    # LiteLLM 模型配置
├── init-workspace.sh      # OpenClaw 容器初始化脚本（配置 Notion/Git 凭证）
├── .env.example           # 环境变量模板
├── .env                   # 实际配置（⚠️ 不入 Git，自行备份）
├── .gitignore
└── data/                  # 持久化数据（不入 Git）
```

## 常用命令

```bash
# 查看所有服务状态
docker compose ps

# 查看日志
docker compose logs -f openclaw
docker compose logs -f litellm

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

项目通过 **GitHub Actions + Self-hosted Runner** 实现自动部署：当 `docker-compose.yml`、`litellm_config.yaml` 或 workflow 文件变更并合入 `main` 时，自动在服务器上执行 `docker compose up`。

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
- `litellm_config.yaml`
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

## 安全说明

1. 端口仅绑定 `127.0.0.1`（除飞书 webhook 端口），通过 SSH 隧道访问
2. `.env` 已被 `.gitignore` 排除，敏感信息不会提交
3. 服务间通过 Docker 内部网络通信，不经过宿主机
4. Copilot Proxy Token 有时效性，即使泄露影响有限
5. Notion/GitHub PAT 建议使用最小权限原则
