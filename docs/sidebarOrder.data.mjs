import { getSidebarOrder } from './.vitepress/sidebarData'

export default {
    load() {
        return getSidebarOrder()
    }
}
