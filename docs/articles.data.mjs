import { createContentLoader } from 'vitepress'
import { execSync } from 'child_process'
import path from 'path'
import fs from 'fs'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

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

export default createContentLoader('notes/*.md', {
    includeSrc: false,
    transform(rawData) {
        return rawData
            .filter(page => page.url !== '/notes/') // 排除索引页
            .map(page => {
                // 构建完整文件路径：从 URL 推导出文件路径
                // URL 格式: /notes/xxx.html -> 文件: notes/xxx.md
                const urlPath = page.url.replace(/\.html$/, '.md').replace(/^\//, '')
                const filePath = path.resolve(__dirname, urlPath)

                const { created, modified } = getGitTimestamps(filePath)

                // 从 frontmatter 获取标题，或从文件内容提取，或从 URL 生成
                const title = page.frontmatter?.title || extractTitle(filePath, page.url)

                return {
                    title,
                    url: page.url,
                    created,
                    modified
                }
            })
    }
})
