import { memo } from 'react'
import { ScrollView, TouchableOpacity, View, StyleSheet } from 'react-native'
import { useI18n } from '@/lang'
import { useNavActiveId, useStatusbarHeight } from '@/store/common/hook'
import { useTheme } from '@/store/theme/hook'
import { Icon } from '@/components/common/Icon'
import { confirmDialog, createStyle, exitApp as backHome } from '@/utils/tools'
import { NAV_MENUS } from '@/config/constant'
import type { InitState } from '@/store/common/state'
// import { navigations } from '@/navigation'
// import commonState from '@/store/common/state'
import { exitApp, setNavActiveId } from '@/core/common'
import Text from '@/components/common/Text'
import { useSettingValue } from '@/store/setting/hook'
import { useIsGlass } from '@/theme/glass'
import GlassView from '@/components/common/GlassView'

const styles = createStyle({
  container: {
    flex: 1,
    // alignItems: 'center',
    // justifyContent: 'center',
    // padding: 10,
  },
  header: {
    paddingTop: 40,
    paddingBottom: 50,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
  },
  headerText: {
    textAlign: 'center',
    marginLeft: 16,
  },
  menus: {
    flex: 1,
  },
  list: {
    paddingTop: 10,
    paddingBottom: 10,
  },
  menuItem: {
    flexDirection: 'row',
    paddingTop: 13,
    paddingBottom: 13,
    paddingLeft: 25,
    paddingRight: 25,
    alignItems: 'center',
    // backgroundColor: 'rgba(0, 0, 0, 0.2)',
  },
  iconContent: {
    width: 24,
    alignItems: 'center',
  },
  text: {
    paddingLeft: 20,
    // fontWeight: '500',
  },
})

const Header = () => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const statusBarHeight = useStatusbarHeight()
  return (
    <View style={{ paddingTop: statusBarHeight, backgroundColor: isGlass ? 'transparent' : theme['c-primary-light-700-alpha-500'] }}>
      <View style={styles.header}>
        <Icon name="logo" color={isGlass ? '#F5F2F1' : theme['c-primary-dark-100-alpha-300']} size={28} />
        <Text style={styles.headerText} size={28} color={isGlass ? '#F5F2F1' : theme['c-primary-dark-100-alpha-300']}>LX Music</Text>
      </View>
    </View>
  )
}

type IdType = InitState['navActiveId'] | 'nav_exit' | 'back_home'

const MenuItem = ({ id, icon, onPress }: {
  id: IdType
  icon: string
  onPress: (id: IdType) => void
}) => {
  const t = useI18n()
  const activeId = useNavActiveId()
  const theme = useTheme()
  const isGlass = useIsGlass()
  const activeStyle = isGlass ? {
    marginHorizontal: 12,
    borderRadius: 14,
    backgroundColor: 'rgba(242, 120, 104, 0.24)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.35)',
  } : {}
  const normalStyle = isGlass ? { marginHorizontal: 12, borderRadius: 14 } : {}

  return activeId == id
    ? <View style={StyleSheet.compose(styles.menuItem, activeStyle)}>
        <View style={styles.iconContent}>
          <Icon name={icon} size={20} color={isGlass ? '#F5F2F1' : theme['c-primary-font-active']} />
        </View>
        <Text style={styles.text} color={isGlass ? '#ffffff' : theme['c-primary-font']}>{t(id)}</Text>
      </View>
    : <TouchableOpacity style={StyleSheet.compose(styles.menuItem, normalStyle)} onPress={() => { onPress(id) }}>
        <View style={styles.iconContent}>
          <Icon name={icon} size={20} color={isGlass ? '#F5F2F1' : theme['c-font-label']} />
        </View>
        <Text style={styles.text} color={isGlass ? '#F5F2F1' : undefined}>{t(id)}</Text>
      </TouchableOpacity>
}

export default memo(() => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  // console.log('render drawer nav')
  const showBackBtn = useSettingValue('common.showBackBtn')
  const showExitBtn = useSettingValue('common.showExitBtn')

  const handlePress = (id: IdType) => {
    switch (id) {
      case 'nav_exit':
        void confirmDialog({
          message: global.i18n.t('exit_app_tip'),
          confirmButtonText: global.i18n.t('list_remove_tip_button'),
        }).then(isExit => {
          if (!isExit) return
          exitApp('Exit Btn')
        })
        return
      case 'back_home':
        backHome()
        return
    }

    global.app_event.changeMenuVisible(false)
    setNavActiveId(id)
  }


  return (
    <GlassView material="regular" radius={0} highlight={false} border={false} shadow={false} style={{ ...styles.container, ...(isGlass ? {} : { backgroundColor: theme['c-content-background'] }) }}>
      <Header />
      <ScrollView style={styles.menus}>
        <View style={styles.list}>
          {NAV_MENUS.map(menu => <MenuItem key={menu.id} id={menu.id} icon={menu.icon} onPress={handlePress} />)}
        </View>
      </ScrollView>

      {
        showBackBtn ? <MenuItem id="back_home" icon="home" onPress={handlePress} /> : null
      }
      {
        showExitBtn ? <MenuItem id="nav_exit" icon="exit2" onPress={handlePress} /> : null
      }
    </GlassView>
  )
})

