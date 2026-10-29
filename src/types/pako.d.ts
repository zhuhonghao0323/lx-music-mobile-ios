/**
 * pako 的类型声明
 *
 * pako 2.x 没有内置 TypeScript 类型（上游 devDependencies 里也没装 @types/pako），
 * 而 iOS 的 fs 实现需要用它做 gzip/unGzip（同步功能的 `cg_` 消息压缩依赖这个格式）。
 *
 * 这里只声明实际用到的两个 API，避免为了两个函数再引入一个 @types 包。
 */
declare module 'pako' {
  type Data = Uint8Array | ArrayBuffer | string

  export function gzip(data: Data, options?: Record<string, unknown>): Uint8Array
  export function ungzip(data: Data, options?: Record<string, unknown>): Uint8Array
}
