# Beans 跨端同步协议（WebDAV）

> 目标：iPhone 与桌面端共享同一份音乐库与播放进度。协议刻意做成「**单文件 + 整体合并**」，任何支持 WebDAV 的网盘都能用（夸克、坚果云、Nextcloud、Alist…）。

## 1. 远端文件

```
<远程目录>/beans-sync.json
```

- 默认远程目录：`/BeansMusic`（不存在时客户端逐级 MKCOL 创建）
- 编码：UTF-8 JSON
- 单文件整体读写，不做分片

## 2. 文档结构

```jsonc
{
  "schema": "beans.sync.v1",
  "revision": 12,                 // 每次写入 +1，仅用于观测
  "updatedAt": 1795828789000,     // 毫秒时间戳
  "deviceId": "0B7C…",            // 写入方设备 id
  "deviceName": "邵芳的 iPhone",
  "playlists": [
    {
      "id": "A1B2C3D4-…",        // UUID 字符串，跨端稳定主键
      "name": "我的收藏歌单",
      "createdAt": 1795000000000,
      "updatedAt": 1795828789000, // 合并依据
      "songs": [
        {
          "id": 123456,
          "name": "Yesterday Once More",
          "artists": "Carpenters",
          "album": "Yesterday Once More: Greatest Hits",
          "coverURL": "https://…",
          "duration": 238.4,
          "source": "netease",     // netease|qq|kugou|migu|bodian|kuwo|qishui
          "qqMid": null,
          "qqMediaMid": null,
          "kugouHash": null,
          "kugouAlbumAudioId": null,
          "kugouAlbumId": null,
          "kugouQualityHashes": null,
          "miguCopyrightId": null,
          "miguLyricUrl": null,
          "qishuiTrackID": null,
          "fee": 0
        }
      ]
    }
  ],
  "tombstones": [
    { "id": "A1B2C3D4-…", "deletedAt": 1795828700000 }
  ],
  "playback": {
    "song": { /* 同上 Song 结构，可为 null */ },
    "position": 83.2,             // 秒
    "duration": 238.4,
    "isPlaying": true,
    "playMode": "sequential",     // sequential|repeatOne|shuffle
    "updatedAt": 1795828790000,
    "deviceId": "0B7C…"
  },
  "devices": {
    "0B7C…": { "name": "邵芳的 iPhone", "lastSyncAt": 1795828790000 }
  }
}
```

### 歌曲对象

`Song` 是 App 的原生模型，字段与 iOS 持久化完全一致。桌面端只需要保留全部字段并原样回写，**不要裁剪**，否则 iOS 端会丢失音源定位信息（`qqMid` / `kugouHash` / `qishuiTrackID` 等）。

`source + id` 构成跨平台唯一键：

| source | 唯一键 |
|---|---|
| netease | `netease-<id>` |
| qq | `qq-<id>` |
| kugou | `kugou-<id>` |
| migu | `migu-<id>` |
| bodian | `bodian-<id>` |
| kuwo | `kuwo-<id>` |
| qishui | `qishui-<qishuiTrackID>` |

## 3. 同步流程

```
1. PROPFIND 根地址（连通性）
2. MKCOL 逐级创建远程目录
3. GET beans-sync.json        → 404 视为空文档
4. 构建本地快照（local）
5. merge(local, remote)
6. PUT 合并结果（带 If-Match: <etag>）
   └ 412 冲突 → 重新 GET + 重新 merge + 再 PUT 一次
7. 把合并结果应用到本地
```

### 合并规则

**歌单**：按 `id` 取并集，同一 `id` 取 `updatedAt` 较大者（LWW）。

**删除**：用墓碑而不是「消失即删除」，否则另一端的旧数据会把歌单复活。

- `tombstones[id] = max(两端 deletedAt)`
- 若歌单 `updatedAt > deletedAt`（删除后又被编辑），撤销墓碑、保留歌单
- 否则从并集中移除

**播放状态**：取 `playback.updatedAt` 较大者。iOS 端的规则是：

- 正在播放 → 每次同步刷新 `updatedAt`（进度持续前进）
- 暂停但歌曲变了 → 刷新
- 暂停且没变化 → 沿用旧时间戳（让另一台设备的进度胜出）

**设备表**：按 `deviceId` 合并，记录各端最后同步时间。

## 4. WebDAV 细节

| 操作 | 方法 | 说明 |
|---|---|---|
| 测试连接 | `PROPFIND /` | `Depth: 0`，期望 207 |
| 建目录 | `MKCOL` | 已存在返回 405，视为成功 |
| 读取 | `GET` | 404 = 空文档 |
| 写入 | `PUT` | `Content-Type: application/json`，带 `If-Match` 防并发覆盖 |

- 认证：HTTP Basic
- 常见服务：
  - 坚果云：`https://dav.jianguoyun.com/dav/`，账号为坚果云邮箱，密码用「第三方应用管理」生成的应用密码
  - 夸克网盘：**官方不提供 WebDAV**，需先用 Alist / OpenList 挂载夸克，再连接 Alist 的 `/dav`
  - 只读桥接（QDAV 等）不能用于本协议，因为同步需要写入 `beans-sync.json`
  - Nextcloud：`https://<域名>/remote.php/dav/files/<用户名>`
  - Alist：`http://<地址>:5244/dav`

## 5. 版本演进

- `schema` 固定为 `beans.sync.v1`
- 新增字段必须可选，旧客户端忽略即可
- 破坏性变更升 `beans.sync.v2`，并通过文件内 `schema` 判断，不做隐式兼容

## 6. 桌面端接入

`desktop-sync/` 提供了零依赖的 Node 参考实现：

```bash
node desktop-sync/src/cli.js test --url https://dav.example.com --user me --pass secret
node desktop-sync/src/cli.js sync --url https://dav.example.com --user me --pass secret \
  --dir /BeansMusic --library ./library.json
```

`library.json` 是桌面端本地的同结构文档（至少包含 `playlists`）。`sync` 会完成 拉取 → 合并 → 写回 → 输出合并结果，Electron 主进程可直接复用 `sync.js` 里的 `mergeDocuments`。
