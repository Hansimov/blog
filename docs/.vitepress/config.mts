import { defineConfig, type DefaultTheme } from 'vitepress'

// https://vitepress.dev/reference/site-config
// https://github.com/vuejs/vitepress/blob/main/docs/.vitepress/config/en.ts

export default defineConfig({
  title: "Hansimov's Blog",
  description: "Software and AI",
  base: "/blog/",
  themeConfig: {
    // https://vitepress.dev/reference/default-theme-config
    nav: nav(),
    sidebar: {
      "/notes/": {
        base: "/notes/",
        items: sidebarNotes()
      }
    },
    outline: "deep",
    socialLinks: [
      { icon: 'github', link: 'https://github.com/Hansimov/blog' }
    ]
  },
  markdown: {
    // lineNumbers: true,
  },
  lastUpdated: true,
})


function nav(): DefaultTheme.NavItem[] {
  return [
    { text: 'Home', link: '/', activeMatch: "/", },
    {
      text: "Notes", link: "/notes/vitepress-init", activeMatch: "/notes/"
    }
  ]
}

function sidebarNotes(): DefaultTheme.SidebarItem[] {
  return [
    {
      text: 'Workflows',
      collapsed: false,
      items: [
        { text: 'Multiple Github accounts on same machine', link: '/multi-github-account' },
        { text: 'VitePress initialization and setup', link: '/vitepress-init' },
      ]
    }
  ]
}
