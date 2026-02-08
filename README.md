# OpenClaw Docker 部署

通过 Docker Compose 一键部署 OpenClaw AI 助手，集成 Azure OpenAI 和 GitHub Copilot 模型。

## 架构

```
飞书/Web ──→ OpenClaw ──→ LiteLLM ──→ Azure OpenAI (GPT 5.2)
                             │
                             └──→ Copilot Proxy ──→ GitHub Copilot
                                                     ├─ Claude Opus 4.6
                                                     ├─ Claude Opus 4.5
                                                     └─ Claude Sonnet 4.5
```

| 服务 | 作用 | 端口 |
|------|------|------|
| **openclaw** | AI 助手主体（飞书集成、网关） | 18789 (localhost) |
| **litellm** | 统一模型网关，多模型路由 | 4000 (内部) |
| **copilot-proxy** | GitHub Copilot API 代理 | 3001 (localhost) |
| **postgres** | LiteLLM 数据库 | 5432 (内部) |

## 快速开始

### 1. 准备配置

```bash
cp .env.example .env
```

编辑 `.env` 填入必填项：

| 变量 | 说明 | 获取方式 |
|------|------|----------|
| `GITHUB_TOKEN` | GitHub PAT | [github.com/settings/tokens](https://github.com/settings/tokens) |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI 密钥 | Azure Portal |
| `AZURE_OPENAI_ENDPOINT` | Azure OpenAI 端点 | Azure Portal |
| `FEISHU_APP_ID` | 飞书 App ID | [open.feishu.cn](https://open.feishu.cn) |
| `FEISHU_APP_SECRET` | 飞书 App Secret | [open.feishu.cn](https://open.feishu.cn) |

### 2. 一键部署

```bash
chmod +x start.sh
./start.sh
```

脚本会自动：
- 检查 Docker 环境
- 生成内部密钥（LiteLLM Master Key、Gateway Token 等）
- 启动所有服务
- 注册模型到 OpenClaw

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

> **注意**: `ghu_` token 有效期有限（约 30 分钟），过期后需重新生成。

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

默认模型：`openai/claude-opus-4-6`

## 文件结构

```
.
├── docker-compose.yml     # 服务编排（4 个服务）
├── litellm_config.yaml    # LiteLLM 模型配置
├── init-models.py         # OpenClaw 模型注册脚本
├── start.sh               # 一键部署脚本
├── .env.example           # 环境变量模板
├── .env                   # 实际配置（不入 Git）
├── .gitignore
└── data/                  # 持久化数据（不入 Git）
    ├── postgres/
    ├── litellm/
    ├── copilot-proxy/
    └── openclaw/
```

## 常用命令

```bash
# 查看所有服务状态
docker compose ps

# 查看日志
docker compose logs -f openclaw
docker compose logs -f litellm
docker compose logs -f copilot-proxy

# 重启服务
docker compose restart openclaw

# 停止所有服务
docker compose down

# 查看 OpenClaw 可用模型
docker compose exec openclaw node dist/index.js models list --all
```

## 安全说明

1. **所有端口仅绑定 `127.0.0.1`**，不暴露到公网，通过 SSH 隧道访问
2. **`.env` 已被 `.gitignore` 排除**，敏感信息不会提交到 Git
3. **内部密钥自动生成**，无需手动创建
4. **服务间通信通过 Docker 内部网络**，不经过宿主机
5. **Copilot Proxy Token 有时效性**，即使泄露影响有限

## 迁移到新服务器

```bash
# 在新服务器上
scp -r user@old-server:~/claw-docker/data ./data     # 迁移数据
scp user@old-server:~/claw-docker/.env ./.env          # 迁移配置
./start.sh                                             # 启动服务
```
