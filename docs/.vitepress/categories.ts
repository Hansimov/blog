// 分类配置，供导航和分类页面共用
export const categoryItems = [
    { text: "Networks", link: "/categories/networks" },
    { text: "Tools", link: "/categories/tools" },
    { text: "Softwares", link: "/categories/softwares" },
    { text: "Databases", link: "/categories/databases" },
    { text: "Workflows", link: "/categories/workflows" },
    { text: "Ubuntu", link: "/categories/ubuntu" },
    { text: "LLMs", link: "/categories/llms" },
    { text: "Configs", link: "/categories/configs" }
]

// 从 sidebar 配置中提取的文章顺序，用于分类页面的默认排序
export const sidebarOrder: Record<string, string[]> = {
    "Networks": [
        "frp-proxy", "frp-reverse-proxy", "cf-tunnel", "v2ray", "proxy-forward",
        "website-dns", "certbot-aliyun", "ddns-go", "zerotier", "merak",
        "ipv6-interface", "ip-static", "switch"
    ],
    "Tools": [
        "remote-ssh", "vscode", "vscode-snippets", "vscode-tasks", "tmux",
        "hstr", "zsh", "nethogs", "grafana"
    ],
    "Softwares": [
        "linux-cmds", "conda", "git", "git-cmds", "git-mirror", "go", "docker",
        "nodejs", "bbdown", "whisper", "ffmpeg-cmds", "windows-updates",
        "mobaxterm-issue", "linux-chrome", "chrome-extensions", "tmpfs", "opencv-python-windows"
    ],
    "Databases": [
        "postgresql", "postgresql-cmds", "mongodb", "mongodb-cmds", "redis",
        "elastic-search", "elastic-kibana", "milvus", "qdrant", "clickhouse", "rocksdb", "minio"
    ],
    "Workflows": [
        "vitepress-init", "multi-github-account", "python-package", "python-requirements",
        "python-cprofile", "sync-github-repo", "hf-download", "hf-repo", "boot-tasks",
        "weixin-miniprogram", "apple-us", "server-transport"
    ],
    "Ubuntu": [
        "ubuntu-config", "ubuntu-dual-boot", "ubuntu-sources", "ubuntu-ssh", "ubuntu-gui",
        "ubuntu-disk", "nvidia-driver", "nvidia-container", "gpu-fan", "ipmi", "pve", "pve-ubuntu"
    ],
    "LLMs": [
        "vllm", "vllm-docker", "ollama", "llama-cpp", "qwen-vl", "llama-factory"
    ],
    "Configs": [
        "bash-aliases", "git-bash-aliases"
    ]
}
