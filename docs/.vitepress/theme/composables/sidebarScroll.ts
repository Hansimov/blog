import { onMounted, watch, nextTick } from 'vue'
import { useRoute } from 'vitepress'

// 滚动侧边栏到当前活动项
function scrollToActiveItem() {
    const tryScroll = (attempt = 0) => {
        if (attempt > 5) return

        const activeItem = document.querySelector('.VPSidebarItem.is-active')
        const sidebar = document.querySelector('.VPSidebar')

        if (activeItem && sidebar) {
            const itemRect = activeItem.getBoundingClientRect()
            const sidebarRect = sidebar.getBoundingClientRect()

            if (itemRect.top < sidebarRect.top || itemRect.bottom > sidebarRect.bottom) {
                activeItem.scrollIntoView({
                    behavior: 'smooth',
                    block: 'center'
                })
            }
        } else {
            setTimeout(() => tryScroll(attempt + 1), 100 * (attempt + 1))
        }
    }

    nextTick(() => {
        setTimeout(() => tryScroll(), 100)
    })
}

// 在 setup 中调用，自动处理挂载和路由变化
export function useSidebarScroll() {
    const route = useRoute()

    onMounted(() => {
        scrollToActiveItem()
    })

    watch(
        () => route.path,
        () => scrollToActiveItem()
    )
}
