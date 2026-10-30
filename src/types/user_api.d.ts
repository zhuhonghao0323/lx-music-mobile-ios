declare namespace LX {
  namespace UserApi {
    type UserApiSourceInfoType = 'music'
    type UserApiSourceInfoActions = 'musicUrl' | 'lyric' | 'pic'

    interface UserApiSourceInfo {
      name: string
      type: UserApiSourceInfoType
      actions: UserApiSourceInfoActions[]
      qualitys: LX.Quality[]
    }

    type UserApiSources = Record<LX.Source, UserApiSourceInfo>


    interface UserApiInfo {
      id: string
      name: string
      description: string
      // script: string
      allowShowUpdateAlert: boolean
      author: string
      homepage: string
      version: string
      sources?: UserApiSources

      /**
       * 该音源的来源 URL（仅通过「在线导入」添加的音源才有）。
       * 只有存在这个字段的音源才支持自动/手动更新。
       */
      sourceUrl?: string
      /**
       * 是否参与后台自动更新检查。默认 true。
       * 关闭后仍保留手动更新能力。
       */
      autoUpdate?: boolean
      /**
       * 上次检查更新的时间戳（毫秒），用于按间隔轮询。
       */
      lastCheckTime?: number
      /**
       * 用户是否手动编辑过该音源脚本。
       * 为 true 时自动更新不会静默覆盖，需要用户二次确认。
       */
      userModified?: boolean
    }

    interface UserApiStatus {
      status: boolean
      message?: string
      apiInfo?: UserApiInfo
    }

    interface UserApiUpdateInfo {
      name: string
      description: string
      log: string
      updateUrl?: string
    }

    interface UserApiRequestParams {
      requestKey: string
      data: any
    }
    interface UserApiRequestParams {
      requestKey: string
      data: any
    }
    type UserApiRequestCancelParams = string
    type UserApiSetApiParams = string

    interface UserApiSetAllowUpdateAlertParams {
      id: string
      enable: boolean
    }

    interface ImportUserApi {
      apiInfo: UserApiInfo
      apiList: UserApiInfo[]
    }

  }
}
