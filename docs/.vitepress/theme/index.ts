import { h } from 'vue'
import type { Theme } from 'vitepress'
import DefaultTheme from 'vitepress/theme'
import Comments from './components/Comments.vue'
import RawTextButton from './components/RawTextButton.vue'
import { useSidebarScroll } from './composables/sidebarScroll'
import "./custom.css"
import "vitepress-markdown-timeline/dist/theme/index.css"

export default {
    extends: DefaultTheme,
    Layout() {
        return h(DefaultTheme.Layout, null, {
            'doc-after': () => h(Comments),
            'nav-bar-content-after': () => h(RawTextButton)
        })
    },
    setup() {
        useSidebarScroll()
    }
} satisfies Theme