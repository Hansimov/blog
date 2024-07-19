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
      text: "Notes", items: [
        { text: "Networks", link: "/notes/frp-proxy" },
        { text: "Tools", link: "/notes/remote-ssh" },
        { text: "Softwares", link: "/notes/conda" },
        { text: "Workflows", link: "/notes/vitepress-init" },
        { text: "Ubuntu", link: "/notes/ubuntu-config" },
        { text: "LLMs", link: "/notes/llama-cpp" },
        { text: "Configs", link: "/notes/bash-aliases" }
      ]
    },
    {
      text: "Research", link: "/research/faq"
    }
  ]
}

function sidebarItems(): DefaultTheme.SidebarItem[] {
  // https://vitepress.dev/reference/default-theme-nav#navigation-links
  return {
    "/notes/": [
      {
        text: "Networks",
        base: "/notes",
        collapsed: true,
        items: [
          {
            text: "Use FRP proxy to forward network traffic",
            link: "/frp-proxy"
          },
          {
            text: "使用 FRP 反向代理",
            link: "/frp-reverse-proxy"
          },
          {
            text: "Port local service to public with Cloudflare Tunnel",
            link: "/cf-tunnel"
          },
          {
            text: "安装 v2ray",
            link: "/v2ray"
          },
          {
            text: "网站搭建和域名解析",
            link: "/website-dns"
          },
          {
            text: "使用 certbot 为阿里云域名生成证书",
            link: "/certbot-aliyun"
          }
        ]
      },
      {
        text: "Tools",
        base: "/notes",
        collapsed: true,
        items: [
          {
            text: "在 VSCode 使用 Remote SSH",
            "link": "/remote-ssh"
          },
          {
            text: "VSCode 的一些坑",
            "link": "/vscode"
          },
          {
            text: "Create VSCode snippets",
            link: "/vscode-snippets"
          },
          {
            text: "安装 tmux",
            link: "/tmux"
          },
          {
            text: "安装 hstr",
            "link": "/hstr"
          },
          {
            text: "安装 zsh",
            "link": "/zsh"
          },
          {
            text: "安装 nethogs",
            link: "/nethogs"
          },
        ]
      },
      {
        text: "Softwares",
        base: "/notes",
        collapsed: false,
        items: [
          {
            text: "安装 conda",
            "link": "/conda"
          },
          {
            text: "安装 Git",
            link: "/git"
          },
          {
            text: "Git 常用命令",
            link: "/git-cmds"
          },
          {
            text: "Git 国内镜像",
            link: "/git-mirror"
          },
          {
            text: "安装 Docker",
            link: "/docker"
          },
          {
            text: "安装 node.js 和 npm",
            "link": "/nodejs"
          },
          {
            text: "安装 Postgresql",
            link: "/postgresql"
          },
          {
            text: "Postgresql 常用命令",
            link: "/postgresql-cmds"
          },
          {
            text: "安装 MongoDB",
            link: "/mongodb"
          },
          {
            text: "安装 BBDown",
            link: "/bbdown"
          },
          {
            text: "安装 whisper",
            link: "/whisper"
          },
          {
            text: "ffmpeg 常用命令",
            link: "/ffmpeg-cmds"
          },
          {
            text: "安装 Elastic Search",
            link: "/elastic-search"
          },
          {
            text: "安装 Elastic Kibana",
            link: "/elastic-kibana"
          }
        ]
      },
      {
        text: "Workflows",
        base: "/notes",
        collapsed: true,
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
            text: "Packaging Python Projects",
            link: "/python-package"
          },
          {
            text: "Python 依赖管理",
            "link": "/python-requirements"
          },
          {
            text: "Sync GitHub to Huggingface",
            link: "/sync-github-to-hf"
          },
          {
            text: "下载 Huggingface 文件",
            link: "/hf-download"
          },
          {
            text: "管理 Huggingface 库",
            link: "/hf-repo"
          },
        ]
      },
      {
        text: "Ubuntu",
        base: "/notes",
        collapsed: true,
        items: [
          {
            text: "个人 Ubuntu 配置流程",
            "link": "/ubuntu-config"
          },
          {
            text: "Windows + Ubuntu 双系统",
            "link": "/ubuntu-dual-boot"
          },
          {
            text: "Ubuntu 换国内源",
            "link": "/ubuntu-sources"
          },
          {
            text: "Ubuntu 开启 SSH 服务",
            "link": "/ubuntu-ssh"
          },
          {
            text: "Ubuntu GUI 设置",
            "link": "/ubuntu-gui"
          },
          {
            text: "Ubuntu 安装新硬盘",
            "link": "/ubuntu-disk"
          },
          {
            text: "Ubuntu 安装 NVIDIA 驱动和 CUDA (NVCC)",
            "link": "/nvidia-driver"
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
          },
          {
            text: "Ollama 运行本地 LLM",
            link: "/ollama"
          },
          {
            text: "本地运行 Qwen-VL-Chat-Int4",
            link: "/qwen-vl"
          },
          {
            text: "使用 LLaMA-Factory 微调 LLM",
            link: "/llama-factory"
          }
        ]
      },
      {
        text: "Configs",
        collapsed: true,
        base: "/notes",
        items: [
          {
            text: "配置 bash aliases",
            link: "/bash-aliases"
          },
          {
            text: "(Windows) Git aliases",
            link: "/git-bash-aliases"
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
        text: "Transformers",
        collapsed: false,
        base: "/research",
        items: [
          {
            text: "Vision Transformers",
            link: "/vit"
          }
        ]
      },
      {
        text: "搜索系统",
        collapsed: false,
        base: "/research",
        items: [
          {
            text: "搜索系统文章选读",
            link: "/search-system-papers"
          }
        ]
      }
    ]
  }
}
