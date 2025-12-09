// Sidebar 数据定义
// 每个分类包含: text(显示名称), collapsed(是否折叠), items(文章列表)
// 每篇文章包含: text(标题), link(链接slug)

export const notesCategories = {
    "Networks": {
        collapsed: false,
        items: [
            { text: "Use FRP proxy to forward network traffic", link: "frp-proxy" },
            { text: "使用 FRP 反向代理", link: "frp-reverse-proxy" },
            { text: "使用 Cloudflare Tunnel 将本地服务端口连接到公网域名", link: "cf-tunnel" },
            { text: "安装 v2ray", link: "v2ray" },
            { text: "PVE 代理转发到 VM", link: "proxy-forward" },
            { text: "网站搭建和域名解析", link: "website-dns" },
            { text: "使用 certbot 为阿里云域名生成证书", link: "certbot-aliyun" },
            { text: "使用 ddns-go 将公网动态 IP 解析到域名", link: "ddns-go" },
            { text: "使用 ZeroTier 组网", link: "zerotier" },
            { text: "使用 Merak 组网", link: "merak" },
            { text: "使用 Tailscale 组网", link: "tailscale" },
            { text: "指定任意 IPv6 地址作为出口 IP", link: "ipv6-interface" },
            { text: "设置静态 IP", link: "ip-static" },
            { text: "交换机和路由器互连", link: "switch" }
        ]
    },
    "Tools": {
        collapsed: false,
        items: [
            { text: "在 VSCode 使用 Remote SSH", link: "remote-ssh" },
            { text: "VSCode 常见问题", link: "vscode" },
            { text: "Create VSCode snippets", link: "vscode-snippets" },
            { text: "VSCode 自定义 tasks", link: "vscode-tasks" },
            { text: "安装 tmux", link: "tmux" },
            { text: "安装 hstr", link: "hstr" },
            { text: "安装 zsh", link: "zsh" },
            { text: "安装 nethogs", link: "nethogs" },
            { text: "安装 Grafana", link: "grafana" }
        ]
    },
    "Softwares": {
        collapsed: false,
        items: [
            { text: "Linux 常用命令", link: "linux-cmds" },
            { text: "安装 conda", link: "conda" },
            { text: "安装 Git", link: "git" },
            { text: "Git 常用命令", link: "git-cmds" },
            { text: "Git 国内镜像", link: "git-mirror" },
            { text: "rsync 常用命令", link: "rsync" },
            { text: "安装 GO", link: "go" },
            { text: "安装 Docker", link: "docker" },
            { text: "安装 node.js 和 npm", link: "nodejs" },
            { text: "安装 BBDown", link: "bbdown" },
            { text: "安装 whisper", link: "whisper" },
            { text: "ffmpeg 常用命令", link: "ffmpeg-cmds" },
            { text: "Win 10 关闭自动更新", link: "windows-updates" },
            { text: "MobaXterm 无法接受键盘输入", link: "mobaxterm-issue" },
            { text: "Linux 安装 Chrome 和 ChromeDriver", link: "linux-chrome" },
            { text: "允许新版 Chrome 使用旧版插件", link: "chrome-extensions" },
            { text: "使用 tmpfs 加速文件读写", link: "tmpfs" },
            { text: "Windows 安装 CUDA Toolkit + cuDNN", link: "windows-cuda-cudnn" },
            { text: "Windows 安装支持 GPU 的 opencv-python", link: "windows-opencv-python" }
        ]
    },
    "Databases": {
        collapsed: false,
        items: [
            { text: "安装 Postgresql", link: "postgresql" },
            { text: "Postgresql 常用命令", link: "postgresql-cmds" },
            { text: "安装 MongoDB", link: "mongodb" },
            { text: "MongoDB 常用命令", link: "mongodb-cmds" },
            { text: "安装 Redis", link: "redis" },
            { text: "安装 Elastic Search", link: "elastic-search" },
            { text: "安装 Elastic Kibana", link: "elastic-kibana" },
            { text: "安装 Milvus", link: "milvus" },
            { text: "安装 Qdrant", link: "qdrant" },
            { text: "安装 ClickHouse", link: "clickhouse" },
            { text: "安装 Rocksdb", link: "rocksdb" },
            { text: "安装 MinIO", link: "minio" }
        ]
    },
    "Workflows": {
        collapsed: false,
        items: [
            { text: "使用 VitePress", link: "vitepress-init" },
            { text: "Multiple Github accounts on same machine", link: "multi-github-account" },
            { text: "Python 打包发布", link: "python-package" },
            { text: "Python 依赖管理", link: "python-requirements" },
            { text: "Python 测试性能", link: "python-cprofile" },
            { text: "同步 Github 仓库到其他平台", link: "sync-github-repo" },
            { text: "下载 Huggingface 文件", link: "hf-download" },
            { text: "管理 Huggingface 库", link: "hf-repo" },
            { text: "服务器断电重启任务恢复", link: "boot-tasks" },
            { text: "微信小程序开发", link: "weixin-miniprogram" },
            { text: "苹果手机注册美区账号和充值礼品卡", link: "apple-us" },
            { text: "服务器搬运", link: "server-transport" }
        ]
    },
    "Ubuntu": {
        collapsed: false,
        items: [
            { text: "个人 Ubuntu 配置流程", link: "ubuntu-config" },
            { text: "Windows + Ubuntu 双系统", link: "ubuntu-dual-boot" },
            { text: "Ubuntu 换国内源", link: "ubuntu-sources" },
            { text: "Ubuntu 开启 SSH 服务", link: "ubuntu-ssh" },
            { text: "Ubuntu GUI 设置", link: "ubuntu-gui" },
            { text: "Ubuntu 安装新硬盘", link: "ubuntu-disk" },
            { text: "Ubuntu 安装 NVIDIA 驱动和 CUDA (NVCC)", link: "nvidia-driver" },
            { text: "安装 NVIDIA Container Toolkit", link: "nvidia-container" },
            { text: "Ubuntu 设置 GPU 风扇速度", link: "gpu-fan" },
            { text: "IPMI 访问、设置和常用命令", link: "ipmi" },
            { text: "安装 PVE", link: "pve" },
            { text: "PVE 创建 Ubuntu 虚拟机", link: "pve-ubuntu" },
            { text: "PVE 创建 Windows 10 虚拟机", link: "pve-windows" },
            { text: "激活 Windows", link: "windows-activate" },
        ]
    },
    "LLMs": {
        collapsed: false,
        items: [
            { text: "本地运行 vllm", link: "vllm" },
            { text: "Docker 运行 vllm", link: "vllm-docker" },
            { text: "Ollama 运行本地 LLM", link: "ollama" },
            { text: "Run local LLM with llama-cpp", link: "llama-cpp" },
            { text: "本地运行 Qwen-VL-Chat-Int4", link: "qwen-vl" },
            { text: "使用 LLaMA-Factory 微调 LLM", link: "llama-factory" }
        ]
    },
    "Configs": {
        collapsed: false,
        items: [
            { text: "配置 bash aliases", link: "bash-aliases" },
            { text: "(Windows) Git aliases", link: "git-bash-aliases" }
        ]
    }
}

export const researchCategories = {
    "Transformers": {
        collapsed: false,
        items: [
            { text: "Vision Transformers", link: "vit" }
        ]
    },
    "搜索系统": {
        collapsed: false,
        items: [
            { text: "搜索系统文章选读", link: "search-system-papers" }
        ]
    }
}

// 合并所有分类
export const allCategories = { ...notesCategories, ...researchCategories }

// 生成 slug -> categoryName 的映射
export function getCategoryMap() {
    const map: Record<string, string> = {}
    for (const [categoryName, category] of Object.entries(allCategories)) {
        for (const item of category.items) {
            map[item.link] = categoryName
        }
    }
    return map
}

// 生成 categoryName -> [slug, ...] 的映射
export function getSidebarOrder() {
    const order: Record<string, string[]> = {}
    for (const [categoryName, category] of Object.entries(allCategories)) {
        order[categoryName] = category.items.map(item => item.link)
    }
    return order
}

// 分类数据类型
type CategoryData = {
    collapsed: boolean
    items: { text: string; link: string }[]
}

type Categories = Record<string, CategoryData>

// 转换为 VitePress sidebar 格式
// collapsed 设为 undefined 让 VitePress 自动根据当前路由展开包含活动链接的分组
function toSidebarFormat(categories: Categories, base: string) {
    return Object.entries(categories).map(([name, category]) => ({
        text: name,
        base,
        collapsed: undefined as boolean | undefined,
        items: category.items.map(item => ({
            text: item.text,
            link: `/${item.link}`
        }))
    }))
}

export function getNotesSidebar() {
    return toSidebarFormat(notesCategories, "/notes")
}

export function getResearchSidebar() {
    return [
        { text: "一些自问自答", link: "/research/faq" },
        ...toSidebarFormat(researchCategories, "/research")
    ]
}
