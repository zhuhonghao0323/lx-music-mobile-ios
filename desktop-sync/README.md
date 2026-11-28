# desktop-sync

桌面端同步核心，零依赖，Node 18+。协议见 [`../doc/webdav-sync.md`](../doc/webdav-sync.md)。

iOS 端已经在「设置 → 数据同步（WebDAV）」里实现同一套合并逻辑，桌面端直接复用这里即可。

## 快速验证

```bash
# 连通性
node src/cli.js test --url https://dav.jianguoyun.com/dav/ --user you@example.com --pass 应用授权码

# 同步本地库（library.json 由桌面 App 维护，结构与 beans-sync.json 相同）
node src/cli.js sync --url https://dav.jianguoyun.com/dav/ --user you@example.com --pass 应用授权码 \
  --dir /BeansMusic --library ./library.json

# 只拉远端（查看 iPhone 的当前播放）
node src/cli.js pull --url https://dav.jianguoyun.com/dav/ --user you@example.com --pass 应用授权码 \
  --out ./remote.json
```

## 在 Electron / Node 主进程里使用

```js
import { WebDAVClient } from './desktop-sync/src/webdav.js';
import { syncOnce, describePlayback } from './desktop-sync/src/sync.js';

const client = new WebDAVClient({
  baseURL: 'https://dav.jianguoyun.com/dav/',
  username: 'you@example.com',
  password: '应用授权码',
  directory: '/BeansMusic'
});

// localDoc 从本地数据库读出来，结构与 beans-sync.json 一致
const merged = await syncOnce(client, localDoc, { deviceId: 'desktop', deviceName: 'Mac' });

// 接续 iPhone 的播放进度
const playback = describePlayback(merged);
if (playback) {
  // player.play(playback.source, playback.sourceId, playback.position)
}
```

## 关键约束

- **不要裁剪 song 字段**：`qqMid` / `kugouHash` / `qishuiTrackID` 等是 iOS 端定位音源的关键，丢了就播不了。
- **删除要写墓碑**：直接删除歌单会被另一端的旧数据复活。桌面端删歌单时往 `tombstones` 里加 `{ id, deletedAt }`，并把本地 `updatedAt` 更新时间。
- **播放进度以 `updatedAt` 较新的一方为准**：桌面端暂停时不要刷新 `updatedAt`，否则会覆盖手机上正在播放的进度。
