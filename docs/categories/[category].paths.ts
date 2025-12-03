import { categoryItems } from '../.vitepress/categories'

export default {
    paths() {
        return categoryItems.map(item => ({
            params: {
                category: item.link.replace('/categories/', ''),
                name: item.text
            }
        }))
    }
}
