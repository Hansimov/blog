import { h } from 'vue'
import DefaultTheme from 'vitepress/theme'
import Comments from './components/Comments.vue'
import { useSidebarScroll } from './composables/sidebarScroll'
import "./custom.css"
import "vitepress-markdown-timeline/dist/theme/index.css"

export default {
    extends: DefaultTheme,
    Layout() {
        return h(DefaultTheme.Layout, null, {
            'doc-after': () => h(Comments)
        })
    },
    setup() {
        useSidebarScroll()
    }
}