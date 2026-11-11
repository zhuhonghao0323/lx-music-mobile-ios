import Main from './Main'

/**
 * 内容区。
 *
 * 重构前这里是「左滑抽屉 + Header + Main」，
 * 现在抽屉取消、Header 也由各 Tab 页面自带（主页有自己的顶部栏），
 * 因此只保留 Main（承载三 Tab 与二级页）。
 */
const Content = () => {
  return <Main />
}

export default Content
