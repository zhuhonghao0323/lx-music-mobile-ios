// 跨端合并逻辑：与 iOS 端 WebDAVSyncStore.merge 保持一致
// 详见 doc/webdav-sync.md

export const SCHEMA = 'beans.sync.v1';

export function emptyDocument(overrides = {}) {
  return {
    schema: SCHEMA,
    revision: 0,
    updatedAt: 0,
    deviceId: '',
    deviceName: '',
    playlists: [],
    tombstones: [],
    playback: null,
    devices: {},
    ...overrides
  };
}

function pickPlayback(local, remote) {
  if (local && remote) return (local.updatedAt || 0) >= (remote.updatedAt || 0) ? local : remote;
  return local || remote || null;
}

/**
 * 歌单按 id 并集 + updatedAt LWW；墓碑时间更大的删除生效，但删除后又被编辑的会复活。
 * @returns 合并后的新文档（不修改入参）
 */
export function mergeDocuments(local, remote, { deviceId = '', deviceName = '', now = Date.now() } = {}) {
  const localDoc = local || emptyDocument();
  const remoteDoc = remote || emptyDocument();

  const byId = new Map();
  for (const playlist of remoteDoc.playlists || []) byId.set(playlist.id, playlist);
  for (const playlist of localDoc.playlists || []) {
    const existing = byId.get(playlist.id);
    if (!existing || (playlist.updatedAt || 0) >= (existing.updatedAt || 0)) {
      byId.set(playlist.id, playlist);
    }
  }

  const tombstones = new Map();
  for (const tombstone of [...(remoteDoc.tombstones || []), ...(localDoc.tombstones || [])]) {
    tombstones.set(tombstone.id, Math.max(tombstones.get(tombstone.id) || 0, tombstone.deletedAt || 0));
  }
  for (const [id, deletedAt] of [...tombstones.entries()]) {
    const playlist = byId.get(id);
    if (playlist && (playlist.updatedAt || 0) > deletedAt) {
      tombstones.delete(id);
    } else {
      byId.delete(id);
    }
  }

  const devices = { ...(remoteDoc.devices || {}), ...(localDoc.devices || {}) };
  if (deviceId) devices[deviceId] = { name: deviceName, lastSyncAt: now };

  return {
    schema: SCHEMA,
    revision: Math.max(localDoc.revision || 0, remoteDoc.revision || 0) + 1,
    updatedAt: now,
    deviceId: deviceId || localDoc.deviceId || '',
    deviceName: deviceName || localDoc.deviceName || '',
    playlists: [...byId.values()].sort((a, b) => (a.createdAt || 0) - (b.createdAt || 0)),
    tombstones: [...tombstones.entries()].map(([id, deletedAt]) => ({ id, deletedAt })),
    playback: pickPlayback(localDoc.playback, remoteDoc.playback),
    devices
  };
}

/** 拉取 → 合并 → 写回；412 时重试一次 */
export async function syncOnce(client, localDoc, options) {
  await client.ensureDirectory();
  const first = await client.fetchDoc();
  let merged = mergeDocuments(localDoc, first.doc || emptyDocument(), options);

  try {
    await client.putDoc(merged, first.etag);
  } catch (error) {
    if (error && error.status === 412) {
      const fresh = await client.fetchDoc();
      merged = mergeDocuments(localDoc, fresh.doc || emptyDocument(), options);
      await client.putDoc(merged, fresh.etag);
    } else {
      throw error;
    }
  }
  return merged;
}

/** 给桌面端 UI 用的一行摘要 */
export function describePlayback(doc) {
  const playback = doc && doc.playback;
  if (!playback || !playback.song) return null;
  const total = Math.max(0, Math.floor(playback.position || 0));
  const time = `${Math.floor(total / 60)}:${String(total % 60).padStart(2, '0')}`;
  return {
    title: playback.song.name,
    artists: playback.song.artists,
    position: playback.position,
    duration: playback.duration,
    isPlaying: Boolean(playback.isPlaying),
    source: playback.song.source,
    sourceId: playback.song.id,
    label: `${playback.song.name} — ${playback.song.artists} @ ${time}`
  };
}
