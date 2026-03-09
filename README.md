# OpenClaw Docker 部署 🦞

通过 Docker Compose 一键部署 OpenClaw AI 助手，使用原生 GitHub Copilot 模型支持。

## 架构

```
飞书/Web ──→ OpenClaw ──→ GitHub Copilot（原生 github-copilot provider）
                │              ├─ GPT-5.4
                │              ├─ Claude Opus 4.6
                │              ├─ GPT-5.2
                │              ├─ Gemini 3 Pro
                │              ├─ Gemini 3 Flash
                │              └─ text-embedding-3-small
                │
                ├──→ Notion API（读写页面/数据库）
                └──→ GitHub（workspace 自动备份）
```

| 服务 | 作用 | 端口 |
|------|------|------|
| **openclaw** | AI 助手主体（飞书集成、网关、原生 Copilot 支持） | 18789 |

## 快速开始

### 1. 准备配置

```bash
cp .env.example .env
```

编辑 `.env` 填入必填项：

| 变量 | 必填 | 说明 | 获取方式 |
|------|------|------|----------|
| `COPILOT_GITHUB_TOKEN` | ✅ | GitHub Copilot Token | 见下方「配置 Copilot Token」 |
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

### 3. 配置 Copilot Token

OpenClaw 原生支持 GitHub Copilot，通过设备授权流程登录：

```bash
# 在容器内运行 GitHub 设备登录流程
docker compose exec openclaw node dist/index.js models auth login-github-copilot

# 按提示在浏览器中完成 GitHub 设备授权
# 登录成功后 token 会自动保存到 OpenClaw 配置中
```

也可以直接在 `.env` 中设置 `COPILOT_GITHUB_TOKEN`（GitHub OAuth token，`ghu_` 前缀）。

### 4. 访问控制台

```bash
ssh -L 18789:127.0.0.1:18789 user@your-server
# 浏览器打开 http://localhost:18789?token=YOUR_GATEWAY_TOKEN
```

## 数据持久化

所有运行时数据通过 Docker volume 挂载到 `./data/` 目录：

```
data/
└── openclaw/        # ⭐ OpenClaw 核心数据
    ├── config/      # Gateway 配置
    └── workspace/   # Agent workspace（记忆、文件、Git 仓库）
```

## 文件结构

```
.
├── docker-compose.yml     # 服务编排（单容器）
├── .env.example           # 环境变量模板
├── .env                   # 实际配置（⚠️ 不入 Git，自行备份）
├── scripts/
│   └── update.sh          # 一键更新脚本
├── .github/workflows/     # CI/CD 自动部署
├── .gitignore
└── data/                  # 持久化数据（不入 Git）
```

## 更新流程

### 手动更新

```bash
git pull                          # 拉取最新配置
docker compose pull               # 拉取最新镜像
docker compose up -d              # 重启
```

### 自动部署 (GitHub Actions)

项目合入 `main` 分支后会触发自动部署。

**前提条件：**
你需要先在服务器上配置并启动 GitHub **Self-hosted Runner**（详见 GitHub Repo `Settings -> Actions -> Runners`），Action 才能在你的服务器上执行部署指令。

**操作流程：**
本地修改 -> `git commit` -> `git push origin main` -> GitHub Actions 调用 Runner 在服务器上自动更新。
