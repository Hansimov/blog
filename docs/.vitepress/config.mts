import { defineConfig, type DefaultTheme } from "vitepress"

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
  },
  lastUpdated: true,
})


function nav(): DefaultTheme.NavItem[] {
  return [
    {
      text: "Home", link: "/", activeMatch: "/",
    },
    {
      text: "Notes", link: "/notes/vitepress-init", activeMatch: "/notes/"
    }
  ]
}

function sidebarNotes(): DefaultTheme.SidebarItem[] {
  return [
    {
      text: "Workflows",
      collapsed: false,
      items: [
        {
          text: "VitePress initialization and setup",
          link: "/vitepress-init"
        },
        {
          text: "Multiple Github accounts on same machine",
          link: "/multi-github-account"
        },
        {
          text: "Use FRP proxy to forward network traffic",
          link: "/frp-proxy"
        },
        {
          text: "Run LLMs locally wtih llama-cpp",
          link: "/llama-cpp"
        },
        {
          text: "Port local service to public with Cloudflare Tunnel",
          link: "/cf-tunnel"
        }
      ]
    },
    {
      text: "Configs",
      collapsed: false,
      items: [
        {
          text: "(Linux) Tmux configs",
          link: "/tmux-configs"
        },
        {
          text: "(Linux) Bash aliases",
          link: "/bash-aliases"
        },
        {
          text: "(Windows) Git aliases",
          link: "/git-bash-aliases"
        }
      ]
    },
    {
      text: "Scripts",
      collapsed: false,
      items: [
        {
          text: "Logger template",
          link: "/logger"
        }
      ]
    }
  ]
}
