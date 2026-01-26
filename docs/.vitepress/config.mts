import { defineConfig, type DefaultTheme } from "vitepress"
import timeline from "vitepress-markdown-timeline"
import { notesCategoryItems, researchCategoryItems } from "./categories"
import { getNotesSidebar, getResearchSidebar } from "./sidebarData"
import fs from "fs"
import path from "path"

// https://vitepress.dev/reference/site-config
// https://github.com/vuejs/vitepress/blob/main/docs/.vitepress/config/en.ts
// https://github.com/vuejs/vitepress/blob/main/template/.vitepress/config.js

export default defineConfig({
  title: "Hansimov's Blog",
  description: "Software and AI",
  base: "/blog/",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: navItems(),
    sidebar: sidebarItems(),
    outline: "deep",
    search: {
      provider: "local",
      options: {
        miniSearch: {
          searchOptions: {
            fuzzy: false,
            combineWith: "AND"
          }
        },
      }
    },
    socialLinks: [
      { icon: "github", link: "https://github.com/Hansimov/blog" }
    ]
  },
  markdown: {
    // lineNumbers: true,
    languageAlias: {
      'env': 'shell',
      'conf': 'ini',
      'ssh': 'ini',
      'service': 'ini'
    },
    config: (md) => {
      md.use(timeline);
    }
  },
  lastUpdated: true,
  ignoreDeadLinks: true,
  vite: {
    server: {
      allowedHosts: true
    }
  },
  async buildEnd(siteConfig) {
    // 复制 .md 文件到输出目录，以便"纯文本"按钮可以 fetch 原始 markdown
    const srcDir = siteConfig.srcDir
    const outDir = siteConfig.outDir

    function copyMdFiles(dir: string, baseDir: string) {
      const items = fs.readdirSync(dir)
      for (const item of items) {
        const srcPath = path.join(dir, item)
        const stat = fs.statSync(srcPath)
        if (stat.isDirectory()) {
          // 跳过 .vitepress 目录
          if (item !== '.vitepress') {
            copyMdFiles(srcPath, baseDir)
          }
        } else if (item.endsWith('.md')) {
          const relativePath = path.relative(baseDir, srcPath)
          const destPath = path.join(outDir, relativePath)
          fs.mkdirSync(path.dirname(destPath), { recursive: true })
          fs.copyFileSync(srcPath, destPath)
        }
      }
    }

    copyMdFiles(srcDir, srcDir)
  }
})


function navItems(): DefaultTheme.NavItem[] {
  return [
    {
      text: "Home", link: "/"
    },
    {
      text: "Notes", items: notesCategoryItems
    },
    {
      text: "Research", items: researchCategoryItems
    }
  ]
}

function sidebarItems() {
  return {
    "/notes/": getNotesSidebar(),
    "/research/": getResearchSidebar()
  }
}
