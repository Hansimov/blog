import { createContentLoader } from 'vitepress'
import { execSync } from 'child_process'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

// 从 config.mts 读取 sidebar 配置来构建分类映射
function buildCategoryMap() {
    const configPath = path.resolve(__dirname, '.vitepress/config.mts')
    const configContent = fs.readFileSync(configPath, 'utf-8')

    const categoryMap = {}

    // 使用更灵活的方式解析 sidebar 配置
    // 首先找到所有包含 text 和 items 的分类块
    // 格式可能是: { text: "CategoryName", base: "/notes", collapsed: true, items: [...] }
    // 或者: { text: "CategoryName", collapsed: true, base: "/notes", items: [...] }

    // 匹配包含 items 数组的分类块（带有嵌套的 items）
    const categoryRegex = /\{\s*(?:[^{}]*?)text:\s*["']([^"']+)["'](?:[^{}]*?)items:\s*\[([\s\S]*?)\]\s*\}/g

    let match
    while ((match = categoryRegex.exec(configContent)) !== null) {
        const categoryName = match[1]
        const itemsBlock = match[2]

        // 检查这是否是一个带有嵌套项目的分类块（而不是简单的导航项）
        // 通过检查 itemsBlock 中是否有 link 属性来判断
        if (!itemsBlock.includes('link')) {
            continue
        }

        // 从 items 块中提取所有 link（支持 link: 和 "link": 两种格式）
        const linkRegex = /"?link"?:\s*["']([^"']+)["']/g
        let linkMatch
        while ((linkMatch = linkRegex.exec(itemsBlock)) !== null) {
            const link = linkMatch[1].replace(/^\//, '') // 去掉开头的 /
            categoryMap[link] = categoryName
        }
    }

    return categoryMap
}

const categoryMap = buildCategoryMap()

function getCategory(url) {
    const slug = url.split('/').pop()?.replace('.html', '') || ''
    return categoryMap[slug] || 'Other'
}

function getGitTimestamps(filePath) {
    if (!filePath || !fs.existsSync(filePath)) {
        return { created: Date.now(), modified: Date.now() }
    }

    try {
        const cwd = path.dirname(filePath)

        // 获取文件首次提交时间（创建时间）
        const createdOutput = execSync(
            `git log --follow --format=%at --reverse -- "${path.basename(filePath)}" | head -1`,
            { cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }
        ).trim()

        // 获取文件最后修改时间
        const modifiedOutput = execSync(
            `git log -1 --format=%at -- "${path.basename(filePath)}"`,
            { cwd, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }
        ).trim()

        const created = createdOutput ? parseInt(createdOutput) * 1000 : Date.now()
        const modified = modifiedOutput ? parseInt(modifiedOutput) * 1000 : Date.now()

        return { created, modified }
    } catch (e) {
        // 如果 git 命令失败，返回当前时间
        return { created: Date.now(), modified: Date.now() }
    }
}

function extractTitle(filePath, url) {
    try {
        if (filePath && fs.existsSync(filePath)) {
            const content = fs.readFileSync(filePath, 'utf-8')
            // 匹配第一个 # 标题
            const match = content.match(/^#\s+(.+)$/m)
            if (match) {
                return match[1].trim()
            }
        }
    } catch (e) {
        // ignore
    }
    // 从 URL 生成标题作为后备
    return url.split('/').pop()?.replace('.html', '').replace(/-/g, ' ') || 'Untitled'
}

export default createContentLoader(['notes/*.md', 'research/*.md'], {
    includeSrc: false,
    transform(rawData) {
        return rawData
            .filter(page => page.url !== '/notes/' && page.url !== '/research/') // 排除索引页
            .map(page => {
                // 构建完整文件路径：从 URL 推导出文件路径
                // URL 格式: /notes/xxx.html -> 文件: notes/xxx.md
                // URL 格式: /research/xxx.html -> 文件: research/xxx.md
                const urlPath = page.url.replace(/\.html$/, '.md').replace(/^\//, '')
                const filePath = path.resolve(__dirname, urlPath)

                const { created, modified } = getGitTimestamps(filePath)

                // 从 frontmatter 获取标题，或从文件内容提取，或从 URL 生成
                const title = page.frontmatter?.title || extractTitle(filePath, page.url)

                // 获取分类
                const category = getCategory(page.url)

                return {
                    title,
                    url: page.url,
                    category,
                    created,
                    modified
                }
            })
    }
})
