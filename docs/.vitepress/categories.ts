// Notes 分类配置，供导航和分类页面共用
export const notesCategoryItems = [
    { text: "Networks", link: "/categories/networks" },
    { text: "Tools", link: "/categories/tools" },
    { text: "Softwares", link: "/categories/softwares" },
    { text: "Databases", link: "/categories/databases" },
    { text: "Workflows", link: "/categories/workflows" },
    { text: "Ubuntu", link: "/categories/ubuntu" },
    { text: "LLMs", link: "/categories/llms" },
    { text: "Configs", link: "/categories/configs" }
]

// Research 分类配置
export const researchCategoryItems = [
    { text: "Transformers", link: "/categories/transformers" },
    { text: "搜索系统", link: "/categories/search" }
]

// 首页显示的分类
export const homeCategoryItems = [
    { text: "Networks", link: "/categories/networks" },
    { text: "Tools", link: "/categories/tools" },
    { text: "Softwares", link: "/categories/softwares" },
    { text: "Databases", link: "/categories/databases" },
    { text: "Workflows", link: "/categories/workflows" },
    { text: "Ubuntu", link: "/categories/ubuntu" },
    { text: "LLMs", link: "/categories/llms" }
]

// 所有分类（用于动态路由生成）
export const categoryItems = [...notesCategoryItems, ...researchCategoryItems]
