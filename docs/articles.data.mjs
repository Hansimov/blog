import { createContentLoader } from 'vitepress'
import { execSync } from 'child_process'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'
import { getCategoryMap } from './.vitepress/sidebarData'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const categoryMap = getCategoryMap()

// 缓存 Git 时间戳，避免重复执行 Git 命令
let gitTimestampsCache = null
let cacheTime = 0
const CACHE_TTL = 90000 // 90秒缓存，开发时避免频繁调用 Git

function getCategory(url) {
    const slug = url.split('/').pop()?.replace('.html', '') || ''
    return categoryMap[slug] || 'Other'
}

// 批量获取所有文件的 Git 时间戳
function getAllGitTimestamps() {
    const now = Date.now()
    if (gitTimestampsCache && (now - cacheTime) < CACHE_TTL) {
        return gitTimestampsCache
    }

    const timestamps = {}
    const repoRoot = path.resolve(__dirname, '..')

    try {
        // 使用单次 git log 命令获取所有文件的最后修改时间
        const modifiedOutput = execSync(
            'git log --format="%at %H" --name-only --diff-filter=ACMR',
            { cwd: repoRoot, encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'], maxBuffer: 10 * 1024 * 1024 }
        )

        let currentTimestamp = null
        for (const line of modifiedOutput.split('\n')) {
            if (!line.trim()) continue

            // 检查是否是时间戳行（格式：timestamp hash）
            const match = line.match(/^(\d+)\s+[a-f0-9]+$/)
            if (match) {
                currentTimestamp = parseInt(match[1]) * 1000
            } else if (currentTimestamp && (line.startsWith('docs/notes/') || line.startsWith('docs/research/'))) {
                // Git 输出的路径是相对于仓库根目录的，如 docs/notes/xxx.md
                const filePath = path.resolve(repoRoot, line)
                if (!timestamps[filePath]) {
                    // 第一次遇到的是最新的修改时间
                    timestamps[filePath] = { modified: currentTimestamp, created: currentTimestamp }
                } else {
                    // 后续遇到的更新创建时间（更早的提交）
                    timestamps[filePath].created = currentTimestamp
                }
            }
        }
    } catch (e) {
        // Git 命令失败时返回空对象
    }

    gitTimestampsCache = timestamps
    cacheTime = now
    return timestamps
}

function getGitTimestamps(filePath) {
    if (!filePath || !fs.existsSync(filePath)) {
        return { created: Date.now(), modified: Date.now() }
    }

    const allTimestamps = getAllGitTimestamps()
    return allTimestamps[filePath] || { created: Date.now(), modified: Date.now() }
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
