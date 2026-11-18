import { useEffect, useRef } from 'react'
import ListNameEdit, { type ListNameEditType } from './MyList/ListNameEdit'
import ListMusicSort, { type ListMusicSortType } from './MyList/ListMusicSort'
import DuplicateMusic, { type DuplicateMusicType } from './MyList/DuplicateMusic'
import ListImportExport, { type ListImportExportType } from './MyList/ListImportExport'
import { handleRemove, handleSync } from './MyList/listAction'
import listState from '@/store/list/state'

type Action = 'sort' | 'duplicate' | 'localFile' | 'sync' | 'import' | 'export' | 'remove'

/**
 * 歌单操作处理器（常驻挂载，不依赖抽屉）。
 *
 * 监听 app_event：
 * - listOperation(action, listId)：执行对应操作
 * - requestCreateList：新建歌单
 *
 * 挂载在需要的页面（我的页 / 歌单页），同一时刻只有一个页面活跃，事件不会冲突。
 */
export default ({ onOperationHandled }: { onOperationHandled?: () => void } = {}) => {
  const listNameEditRef = useRef<ListNameEditType>(null)
  const listMusicSortRef = useRef<ListMusicSortType>(null)
  const duplicateMusicRef = useRef<DuplicateMusicType>(null)
  const listImportExportRef = useRef<ListImportExportType>(null)

  useEffect(() => {
    const findInfo = (id: string): LX.List.MyListInfo | undefined => {
      return (listState.allList as LX.List.MyListInfo[]).find(l => l.id == id) ??
        listState.userList.find(l => l.id == id)
    }

    const handleOperation = (action: Action, listId: string) => {
      const info = findInfo(listId)
      if (!info) return
      // 操作需要 index，这里用列表里的位置近似（多数操作只用 info）
      const index = Math.max(0, listState.userList.findIndex(l => l.id == listId))
      switch (action) {
        case 'sort': listMusicSortRef.current?.show(info); break
        case 'duplicate': duplicateMusicRef.current?.show(info); break
        case 'localFile': listImportExportRef.current?.selectFile(info, index); break
        case 'sync': handleSync(info as LX.List.UserListInfo); break
        case 'import': listImportExportRef.current?.import(info, index); break
        case 'export': listImportExportRef.current?.export(info, index); break
        case 'remove': handleRemove(info as LX.List.UserListInfo); break
        default: break
      }
      onOperationHandled?.()
    }
    const handleCreate = () => {
      listNameEditRef.current?.showCreate(Math.max(0, listState.userList.length - 1))
    }
    global.app_event.on('listOperation', handleOperation)
    global.app_event.on('requestCreateList', handleCreate)
    return () => {
      global.app_event.off('listOperation', handleOperation)
      global.app_event.off('requestCreateList', handleCreate)
    }
  }, [onOperationHandled])

  return (
    <>
      <ListNameEdit ref={listNameEditRef} />
      <ListMusicSort ref={listMusicSortRef} />
      <DuplicateMusic ref={duplicateMusicRef} />
      <ListImportExport ref={listImportExportRef} />
    </>
  )
}
