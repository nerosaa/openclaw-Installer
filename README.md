# OpenClaw 全平台傻瓜式安装器（含扩展中心）

这个脚本现在不只是安装 OpenClaw，还提供了一个“傻瓜式扩展中心”：

- 一键安装 / 更新 / 自动修复 / 卸载
- 菜单常驻循环
- 聊天软件接入模板生成（Telegram/Discord/Slack/飞书/企业微信/钉钉/QQ/微信等）
- 第三方 API 模型接入（OpenAI/Anthropic/Gemini/OpenRouter 等）
- 自定义本地模型接入（Ollama/vLLM/LM Studio/其它）
- 旧模型标记与一键清理
- 一键重启 OpenClaw（后台）
- 系统健康检查
- 扩展配置一键备份与恢复

## 快速开始

```bash
chmod +x openclaw-easy-installer.sh
./openclaw-easy-installer.sh
```

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

## 说明

- 这是“傻瓜式接入层”，负责生成配置和统一入口；具体聊天机器人桥接程序（如你自己的 bot 服务）读取这些配置后即可工作。
- Windows 下若 SDL2 开发环境不完整，建议进入 MSYS2 后补齐相关包。
