import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// 从 config.mts 动态提取文章顺序
function buildSidebarOrder() {
    const configPath = path.resolve(__dirname, '.vitepress/config.mts')
    const configContent = fs.readFileSync(configPath, 'utf-8')

    const sidebarOrder = {}

    // 匹配包含 items 数组的分类块
    const categoryRegex = /\{\s*(?:[^{}]*?)text:\s*["']([^"']+)["'](?:[^{}]*?)items:\s*\[([\s\S]*?)\]\s*\}/g

    let match
    while ((match = categoryRegex.exec(configContent)) !== null) {
        const categoryName = match[1]
        const itemsBlock = match[2]

        if (!itemsBlock.includes('link')) {
            continue
        }

        // 从 items 块中提取所有 link（支持 link: 和 "link": 两种格式）
        const linkRegex = /"?link"?:\s*["']([^"']+)["']/g
        const links = []
        let linkMatch
        while ((linkMatch = linkRegex.exec(itemsBlock)) !== null) {
            const link = linkMatch[1].replace(/^\//, '') // 去掉开头的 /
            links.push(link)
        }

        if (links.length > 0) {
            sidebarOrder[categoryName] = links
        }
    }

    return sidebarOrder
}

export default {
    load() {
        return buildSidebarOrder()
    }
}
