#!/usr/bin/env node
// 桌面端同步 CLI：把本地 library.json 与远端 beans-sync.json 合并
// 用法：
//   node src/cli.js test --url https://dav.example.com --user me --pass secret
//   node src/cli.js sync --url ... --user me --pass secret --dir /BeansMusic --library ./library.json
//   node src/cli.js pull --url ... --user me --pass secret --out ./library.json

import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { WebDAVClient } from './webdav.js';
import { syncOnce, emptyDocument, describePlayback } from './sync.js';

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const args = { command };
  for (let i = 0; i < rest.length; i += 1) {
    const token = rest[i];
    if (!token.startsWith('--')) continue;
    const key = token.slice(2);
    const value = rest[i + 1] && !rest[i + 1].startsWith('--') ? rest[++i] : 'true';
    args[key] = value;
  }
  return args;
}

function clientFromArgs(args) {
  if (!args.url) throw new Error('缺少 --url');
  return new WebDAVClient({
    baseURL: args.url,
    username: args.user || '',
    password: args.pass || '',
    directory: args.dir || '/BeansMusic'
  });
}

async function readLibrary(path) {
  if (!path || !existsSync(path)) return emptyDocument();
  const text = await readFile(path, 'utf8');
  return { ...emptyDocument(), ...JSON.parse(text) };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const client = clientFromArgs(args);

  if (args.command === 'test') {
    await client.ping();
    await client.ensureDirectory();
    console.log(`连接成功：${client.fileURL()}`);
    return;
  }

  if (args.command === 'pull') {
    const { doc } = await client.fetchDoc();
    const output = doc || emptyDocument();
    if (args.out) await writeFile(args.out, JSON.stringify(output, null, 2), 'utf8');
    console.log(JSON.stringify(output.playback || null, null, 2));
    console.log(`已拉取 ${output.playlists.length} 个歌单`);
    return;
  }

  if (args.command === 'sync') {
    const local = await readLibrary(args.library);
    const merged = await syncOnce(client, local, {
      deviceId: args.device || 'desktop',
      deviceName: args.name || 'Desktop'
    });
    if (args.library) {
      await writeFile(args.library, JSON.stringify(merged, null, 2), 'utf8');
    }
    const playback = describePlayback(merged);
    console.log(`同步完成：${merged.playlists.length} 个歌单，revision ${merged.revision}`);
    if (playback) console.log(`上次播放：${playback.label}`);
    return;
  }

  console.log('用法：node src/cli.js <test|sync|pull> --url <WebDAV 地址> [--user 用户名] [--pass 密码] [--dir /BeansMusic] [--library ./library.json]');
}

main().catch((error) => {
  console.error('失败：', error.message || error);
  process.exitCode = 1;
});
