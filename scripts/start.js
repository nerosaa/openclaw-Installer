#!/usr/bin/env node
const { spawn } = require('node:child_process');
const { existsSync } = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const script = path.join(root, 'openclaw-easy-installer.sh');

if (!existsSync(script)) {
  console.error('[ERROR] 未找到安装脚本:', script);
  process.exit(1);
}

const isWin = process.platform === 'win32';
const cmd = isWin ? 'bash' : 'bash';
const args = [script, ...process.argv.slice(2)];

console.log('[INFO] 一键启动 OpenClaw 傻瓜菜单...');
console.log('[INFO] 提示：如在 Windows，请用 Git Bash 或 MSYS2 终端运行 npm start。');

const child = spawn(cmd, args, {
  stdio: 'inherit',
  shell: false
});

child.on('error', (err) => {
  console.error('[ERROR] 启动失败:', err.message);
  if (isWin) {
    console.error('[HINT] 请先安装 Git Bash 或 MSYS2，并确保 bash 在 PATH 中。');
  }
  process.exit(1);
});

child.on('exit', (code, signal) => {
  if (signal) {
    process.exit(1);
  }
  process.exit(code ?? 0);
});
