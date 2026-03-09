# OpenClaw 全平台傻瓜式安装器（含扩展中心）

现在支持真正的 **一条命令自动下载 + 自动安装**。

## 超级傻瓜式一键开始（默认自动安装）

```bash
./bootstrap-openclaw.sh
```

默认执行流程（无人值守）：

1. 自动检查 `node` / `npm`
2. 若缺失，自动调用系统包管理器安装 Node.js
3. 自动执行 `npm start -- --auto-install`
4. 自动安装依赖、下载 OpenClaw 源码、编译并生成启动器

## 仅进入菜单（不立即自动安装）

```bash
./bootstrap-openclaw.sh --menu
```

## 备选启动方式

### 方式 A：你已经有 Node.js

```bash
npm start
```

### 方式 B：传统 Bash 直接启动

```bash
chmod +x openclaw-easy-installer.sh
./openclaw-easy-installer.sh
```

## 已支持的傻瓜能力

- 一键安装 / 更新 / 自动修复 / 卸载
- 菜单常驻循环
- 聊天软件接入模板生成（Telegram/Discord/Slack/飞书/企业微信/钉钉/QQ/微信等）
- 第三方 API 模型接入（OpenAI/Anthropic/Gemini/OpenRouter 等）
- 自定义本地模型接入（Ollama/vLLM/LM Studio/其它）
- 旧模型标记与一键清理
- 一键重启 OpenClaw（后台）
- 系统健康检查
- 扩展配置一键备份与恢复

## 支持平台

- Linux: `apt/dnf/yum/pacman/zypper`
- macOS: `brew`
- Windows（Git Bash/MSYS2）: `winget/choco/msys2 pacman`

## 菜单能力（0-16）

1. 一键安装 OpenClaw
2. 自动修复
3. 更新 OpenClaw
4. 卸载
5. 高级设置（路径/仓库）
6. 仅安装系统依赖
7. 聊天软件接入（生成 .env 模板）
8. 查看聊天软件接入列表
9. 新增模型（第三方 API / 自定义本地）
10. 查看模型列表
11. 标记旧模型
12. 清除旧模型
13. 一键重启 OpenClaw
14. 系统健康检查
15. 备份扩展配置
16. 恢复扩展配置

## 目录说明

默认在安装目录下会创建：

- `hub/models.db`：模型注册表
- `hub/connectors.db`：聊天软件接入记录
- `hub/openclaw.pid`：后台进程 PID
- `hub/backups/`：备份文件
- `integrations/*.env`：聊天软件模板
