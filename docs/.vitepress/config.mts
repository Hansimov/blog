import { defineConfig, type DefaultTheme } from "vitepress"

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
  },
  lastUpdated: true,
})


function navItems(): DefaultTheme.NavItem[] {
  return [
    {
      text: "Home", link: "/"
    },
    {
      text: "Notes", link: "/notes/vitepress-init"
    }
  ]
}

function sidebarItems(): DefaultTheme.SidebarItem[] {
  return [
    {
      text: "Networks",
      collapsed: false,
      base: "/notes",
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
          text: "Port local service to public with Cloudflare Tunnel",
          link: "/cf-tunnel"
        }
      ]
    },
    {
      text: "LLMs",
      collapsed: false,
      base: "/notes",
      items: [
        {
          text: "Run LLMs locally with llama-cpp",
          link: "/llama-cpp"
        },
        {
          text: "Run LLMs locally with vllm",
          link: "/vllm"
        }
      ]
    },
    {
      text: "Configs",
      collapsed: false,
      base: "/notes",
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
      base: "/notes",
      items: [
        {
          text: "Logger template",
          link: "/logger"
        }
      ]
    }
  ]
}
