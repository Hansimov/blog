import { defineConfig, type DefaultTheme } from "vitepress"
import timeline from "vitepress-markdown-timeline"

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
    config: (md) => {
      md.use(timeline);
    }
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
    },
    {
      text: "Research", link: "/research/faq"
    }
  ]
}

function sidebarItems(): DefaultTheme.SidebarItem[] {
  return {
    "/notes/": [
      {
        text: "Networks",
        base: "/notes",
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
            text: "Port local service to public with Cloudflare Tunnel",
            link: "/cf-tunnel"
          }
        ]
      },
      {
        text: "Softwares",
        base: "/notes",
        collapsed: false,
        items: [
          {
            text: "Create VSCode snippets",
            link: "/vscode-snippets"
          },
          {
            text: "Packaging Python Projects",
            link: "/python-package"
          },
        ]
      },
      {
        text: "LLMs",
        collapsed: false,
        base: "/notes",
        items: [
          {
            text: "Run local LLM with llama-cpp",
            link: "/llama-cpp"
          },
          {
            text: "Run local LLM with vllm",
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
            text: "Python logger template",
            link: "/logger"
          }
        ]
      }
    ],
    "/research/": [
      {
        text: "一些自问自答",
        link: "/research/faq"
      },
      {
        text: "写作计划",
        link: "/research/plan"
      },
      {
        text: "Transformers",
        collapsed: false,
        base: "/research",
        items: [
          {
            text: "Vision Transformers",
            link: "/vit"
          }
        ]
      }
    ]
  }
}
