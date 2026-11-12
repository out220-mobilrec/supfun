#!/usr/bin/env node
'use strict';

/**
 * Запуск SUP FUN в разработке одной командой: node scripts/dev.js
 *
 * Поднимает параллельно:
 *   - backend: `npm run start:watch` в server/ (порт PORT, по умолчанию 3000)
 *   - web:     `npm run dev` в web/ (порт WEB_PORT, по умолчанию 5173)
 *
 * Вывод процессов помечается префиксами [server] / [web]. При падении одного
 * из них останавливается вся связка (как concurrently -k).
 *
 * Переменные окружения:
 *   PORT       — порт backend (default 3000)
 *   WEB_PORT   — порт vite (default 5173)
 *   SERVER_DEV — npm-скрипт backend (default start:watch)
 */

const { spawn } = require('child_process');
const http = require('http');
const net = require('net');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const SERVER_DIR = path.join(ROOT, 'server');
const WEB_DIR = path.join(ROOT, 'web');

const SERVER_PORT = Number(process.env.PORT || 3000);
const WEB_PORT = Number(process.env.WEB_PORT || 5173);
const SERVER_DEV = process.env.SERVER_DEV || 'start:watch';

const COLORS = {
  server: '\x1b[36m',
  web: '\x1b[35m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  reset: '\x1b[0m',
};

function portInUse(port) {
  return new Promise((resolve) => {
    const socket = net.connect({ host: '127.0.0.1', port });
    socket.setTimeout(700);
    socket.once('connect', () => {
      socket.destroy();
      resolve(true);
    });
    socket.once('timeout', () => {
      socket.destroy();
      resolve(false);
    });
    socket.once('error', () => resolve(false));
  });
}

/// Отвечает ли на порту живый backend (GET /api/health).
function isOurBackend(port) {
  return new Promise((resolve) => {
    const request = http.get({ host: '127.0.0.1', port, path: '/api/health', timeout: 1500 }, (res) => {
      res.resume();
      resolve(res.statusCode === 200);
    });
    request.on('timeout', () => {
      request.destroy();
      resolve(false);
    });
    request.on('error', () => resolve(false));
  });
}

/// Помечает каждую строку вывода префиксом процесса.
function pipeLines(stream, name) {
  let buffer = '';
  stream.setEncoding('utf8');
  stream.on('data', (chunk) => {
    buffer += chunk;
    const lines = buffer.split(/\r?\n/);
    buffer = lines.pop() ?? '';
    for (const line of lines) {
      if (line.trim() === '') continue;
      process.stdout.write(`${COLORS[name]}[${name}]${COLORS.reset} ${line}\n`);
    }
  });
  stream.on('close', () => {
    if (buffer.trim() !== '') {
      process.stdout.write(`${COLORS[name]}[${name}]${COLORS.reset} ${buffer}\n`);
      buffer = '';
    }
  });
}

function start(name, script, cwd, env, args = '') {
  // shell: true — чтобы npm.cmd нашёлся и на Windows, и в POSIX-оболочках
  const command = `npm run ${script}${args ? ` -- ${args}` : ''}`;
  const child = spawn(command, {
    cwd,
    env: { ...process.env, ...env },
    shell: true,
    windowsHide: true,
  });
  pipeLines(child.stdout, name);
  pipeLines(child.stderr, name);
  return child;
}

function killTree(child) {
  if (!child.pid || child.killed) return;
  if (process.platform === 'win32') {
    // у shell-обёртки есть дочерние node-процессы — снимаем всё дерево
    spawn('taskkill', ['/pid', String(child.pid), '/T', '/F'], { windowsHide: true });
  } else {
    child.kill('SIGTERM');
  }
}

async function main() {
  let serverOnlySkip = false;
  if (await portInUse(SERVER_PORT)) {
    if (await isOurBackend(SERVER_PORT)) {
      process.stdout.write(
        `${COLORS.yellow}На :${SERVER_PORT} уже работает backend SUP FUN — запускаю только web.${COLORS.reset}\n` +
          `${COLORS.dim}Чтобы перезапустить backend: server/stop-server.bat, затем npm run dev${COLORS.reset}\n\n`,
      );
      serverOnlySkip = true;
    } else {
      process.stderr.write(
        `${COLORS.red}Порт ${SERVER_PORT} занят другим процессом — backend не стартует.${COLORS.reset}\n` +
          `${COLORS.dim}Освободите порт (server/stop-server.bat) или укажите другой: $env:PORT=3100; npm run dev${COLORS.reset}\n`,
      );
      process.exitCode = 1;
      return;
    }
  }
  if (await portInUse(WEB_PORT)) {
    process.stdout.write(
      `${COLORS.yellow}Порт ${WEB_PORT} занят — vite выберет другой порт автоматически.${COLORS.reset}\n`,
    );
  }

  process.stdout.write(
    `${COLORS.dim}Запуск SUP FUN: ${serverOnlySkip ? `web (:${WEB_PORT})` : `backend (:${SERVER_PORT}) + web (:${WEB_PORT})`}${COLORS.reset}\n` +
      `${COLORS.dim}API   http://localhost:${SERVER_PORT}/api/health${COLORS.reset}\n` +
      `${COLORS.dim}UI    http://localhost:${WEB_PORT}${COLORS.reset}\n\n`,
  );

  const children = [];
  const server = serverOnlySkip
    ? null
    : start('server', SERVER_DEV, SERVER_DIR, { PORT: String(SERVER_PORT) });
  const web = start(
    'web',
    'dev',
    WEB_DIR,
    {
      WEB_PORT: String(WEB_PORT),
      VITE_API_PROXY: `http://localhost:${SERVER_PORT}`,
    },
    `--port ${WEB_PORT}`,
  );
  if (server) children.push(server);
  children.push(web);

  let closing = false;

  const shutdown = (code) => {
    if (closing) return;
    closing = true;
    for (const child of children) killTree(child);
    process.exitCode = code;
  };

  if (server) {
    server.on('exit', (code) => {
      process.stdout.write(`\n${COLORS.red}[server] завершился (код ${code}) — останавливаю web${COLORS.reset}\n`);
      shutdown(code ?? 1);
    });
  }
  web.on('exit', (code) => {
    if (server) {
      process.stdout.write(`\n${COLORS.red}[web] завершился (код ${code}) — останавливаю backend${COLORS.reset}\n`);
    }
    shutdown(code ?? 0);
  });

  process.on('SIGINT', () => shutdown(0));
  process.on('SIGTERM', () => shutdown(0));
}

main().catch((err) => {
  process.stderr.write(`${COLORS.red}Ошибка запуска: ${err.message}${COLORS.reset}\n`);
  process.exitCode = 1;
});
