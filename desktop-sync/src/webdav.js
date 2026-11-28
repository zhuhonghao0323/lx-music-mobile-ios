// 零依赖 WebDAV 客户端（Node 18+，使用全局 fetch）
// 与 iOS 端 WebDAVClient 行为对齐：PROPFIND 探活 / MKCOL 建目录 / GET / PUT（If-Match）

export class WebDAVError extends Error {
  constructor(message, status) {
    super(message);
    this.name = 'WebDAVError';
    this.status = status;
  }
}

export class WebDAVClient {
  constructor({ baseURL, username = '', password = '', directory = '/BeansMusic' }) {
    if (!baseURL) throw new WebDAVError('缺少 baseURL');
    let normalized = (directory || '/BeansMusic').trim();
    if (!normalized.startsWith('/')) normalized = '/' + normalized;
    while (normalized.length > 1 && normalized.endsWith('/')) normalized = normalized.slice(0, -1);

    this.baseURL = baseURL.replace(/\/+$/, '');
    this.username = username;
    this.password = password;
    this.directory = normalized;
    this.fileName = 'beans-sync.json';
  }

  get authorization() {
    if (!this.username) return null;
    const raw = `${this.username}:${this.password}`;
    return 'Basic ' + Buffer.from(raw, 'utf8').toString('base64');
  }

  fileURL() {
    return `${this.baseURL}${this.directory}/${this.fileName}`;
  }

  async request(method, url, { headers = {}, body } = {}) {
    const finalHeaders = { ...headers };
    const auth = this.authorization;
    if (auth) finalHeaders.Authorization = auth;
    if (body !== undefined && !finalHeaders['Content-Type']) {
      finalHeaders['Content-Type'] = 'application/octet-stream';
    }
    const response = await fetch(url, {
      method,
      headers: finalHeaders,
      body: ['MKCOL', 'PROPFIND', 'PUT'].includes(method) ? body ?? '' : body
    });
    return response;
  }

  async ping() {
    const response = await this.request('PROPFIND', this.baseURL, { headers: { Depth: '0' } });
    if (response.status === 401) throw new WebDAVError('账号或密码不正确（401）', 401);
    if (response.status !== 207 && !(response.status >= 200 && response.status < 300)) {
      throw new WebDAVError(`服务器返回 HTTP ${response.status}`, response.status);
    }
  }

  async ensureDirectory() {
    const segments = this.directory.split('/').filter(Boolean);
    let url = this.baseURL;
    for (const segment of segments) {
      url += '/' + encodeURIComponent(segment);
      const response = await this.request('MKCOL', url);
      const status = response.status;
      if (status === 401) throw new WebDAVError('账号或密码不正确（401）', 401);
      // 405 = 已存在；403 常见于已存在但无写权限，继续走让 PUT 报更准确的错
      if ((status >= 200 && status < 300) || status === 405 || status === 403) continue;
      throw new WebDAVError(`创建目录失败：HTTP ${status}`, status);
    }
  }

  /** @returns {Promise<{doc: object|null, etag: string|null}>} */
  async fetchDoc() {
    const response = await this.request('GET', this.fileURL());
    if (response.status === 404) return { doc: null, etag: null };
    if (response.status === 401) throw new WebDAVError('账号或密码不正确（401）', 401);
    if (!response.ok) throw new WebDAVError(`读取失败：HTTP ${response.status}`, response.status);
    const text = await response.text();
    const doc = text.trim() ? JSON.parse(text) : null;
    return { doc, etag: response.headers.get('etag') };
  }

  async putDoc(doc, etag) {
    const headers = { 'Content-Type': 'application/json; charset=utf-8' };
    if (etag) headers['If-Match'] = etag;
    const response = await this.request('PUT', this.fileURL(), {
      headers,
      body: JSON.stringify(doc)
    });
    if (response.status === 412) throw new WebDAVError('远端文件已被修改（412）', 412);
    if (response.status === 401) throw new WebDAVError('账号或密码不正确（401）', 401);
    if (!response.ok) throw new WebDAVError(`写入失败：HTTP ${response.status}`, response.status);
  }
}
