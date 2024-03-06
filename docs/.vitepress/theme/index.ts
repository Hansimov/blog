import { h } from 'vue'
import "./custom.css"
import DefaultTheme from 'vitepress/theme'
import Comments from './components/Comments.vue'
import "vitepress-markdown-timeline/dist/theme/index.css";

export default {
    extends: DefaultTheme,
    Layout() {
        return h(DefaultTheme.Layout, null, {
            'doc-after': () => h(Comments)
        })
    },
}