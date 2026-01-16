import { defineConfig, type DefaultTheme } from "vitepress"
import timeline from "vitepress-markdown-timeline"
import { notesCategoryItems, researchCategoryItems } from "./categories"
import { getNotesSidebar, getResearchSidebar } from "./sidebarData"

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
      'ssh': 'ini'
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
