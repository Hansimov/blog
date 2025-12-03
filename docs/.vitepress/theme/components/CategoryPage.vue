<script setup lang="ts">
import { ref, computed } from "vue";
import { withBase } from "vitepress";
// @ts-ignore
import { data as articlesData } from "../../../articles.data.mjs";
// @ts-ignore
import { sidebarOrder } from "../../categories";

const props = defineProps<{
  categoryName: string;
}>();

// 排序状态: 'default' | 'created-asc' | 'created-desc' | 'modified-asc' | 'modified-desc'
const sortBy = ref<string>("default");

// 获取该分类下的所有文章
const categoryArticles = computed(() => {
  const articles = articlesData.filter(
    (article: any) => article.category === props.categoryName
  );

  // 根据排序状态排序
  if (sortBy.value === "default") {
    // 使用 sidebar 中的默认顺序
    const order = sidebarOrder[props.categoryName] || [];
    return [...articles].sort((a: any, b: any) => {
      const aSlug = a.url.split("/").pop()?.replace(".html", "") || "";
      const bSlug = b.url.split("/").pop()?.replace(".html", "") || "";
      const aIndex = order.indexOf(aSlug);
      const bIndex = order.indexOf(bSlug);
      // 如果不在 order 中，放到最后
      const aOrder = aIndex === -1 ? 9999 : aIndex;
      const bOrder = bIndex === -1 ? 9999 : bIndex;
      return aOrder - bOrder;
    });
  } else if (sortBy.value === "created-asc") {
    return [...articles].sort((a: any, b: any) => a.created - b.created);
  } else if (sortBy.value === "created-desc") {
    return [...articles].sort((a: any, b: any) => b.created - a.created);
  } else if (sortBy.value === "modified-asc") {
    return [...articles].sort((a: any, b: any) => a.modified - b.modified);
  } else if (sortBy.value === "modified-desc") {
    return [...articles].sort((a: any, b: any) => b.modified - a.modified);
  }
  return articles;
});

function formatDate(timestamp: number): string {
  const date = new Date(timestamp);
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${date.getFullYear()}/${pad(date.getMonth() + 1)}/${pad(
    date.getDate()
  )} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function toggleSort(field: "created" | "modified") {
  const currentField = sortBy.value.split("-")[0];
  const currentDir = sortBy.value.split("-")[1];

  if (currentField === field) {
    // 同一字段：asc -> desc -> default
    if (currentDir === "asc") {
      sortBy.value = `${field}-desc`;
    } else if (currentDir === "desc") {
      sortBy.value = "default";
    } else {
      sortBy.value = `${field}-asc`;
    }
  } else {
    // 切换字段，从升序开始
    sortBy.value = `${field}-asc`;
  }
}

function getSortIcon(field: "created" | "modified"): string {
  const currentField = sortBy.value.split("-")[0];
  const currentDir = sortBy.value.split("-")[1];

  if (currentField === field) {
    if (currentDir === "asc") return "↑";
    if (currentDir === "desc") return "↓";
  }
  return "";
}
</script>

<template>
  <div class="category-page">
    <h1 class="category-title">{{ categoryName }}</h1>
    <p class="category-count">共 {{ categoryArticles.length }} 篇文章</p>

    <div class="article-list" v-if="categoryArticles.length > 0">
      <div class="article-header">
        <span class="header-title">标题</span>
        <span class="header-created sortable" @click="toggleSort('created')">
          发布时间 <span class="sort-icon">{{ getSortIcon("created") }}</span>
        </span>
        <span class="header-modified sortable" @click="toggleSort('modified')">
          修改时间 <span class="sort-icon">{{ getSortIcon("modified") }}</span>
        </span>
      </div>
      <a
        v-for="article in categoryArticles"
        :key="article.url"
        :href="withBase(article.url)"
        class="article-item"
      >
        <span class="article-title" :title="article.title">{{
          article.title
        }}</span>
        <span class="article-created">{{ formatDate(article.created) }}</span>
        <span class="article-modified">{{ formatDate(article.modified) }}</span>
      </a>
    </div>

    <div v-else class="no-articles">暂无文章</div>
  </div>
</template>

<style scoped>
.category-page {
  max-width: 900px;
  margin: 0 auto;
  padding: 24px;
}

.category-title {
  font-size: 28px;
  font-weight: 700;
  color: var(--vp-c-text-1);
  margin: 0 0 8px 0;
  padding-bottom: 16px;
  border-bottom: 2px solid var(--vp-c-brand-1);
}

.category-count {
  font-size: 14px;
  color: var(--vp-c-text-2);
  margin: 0 0 24px 0;
}

.article-list {
  background: var(--vp-c-bg-soft);
  border-radius: 12px;
  padding: 16px 20px;
}

.article-header {
  display: flex;
  align-items: center;
  padding: 8px 0;
  margin-bottom: 8px;
  font-size: 12px;
  font-weight: 600;
  color: var(--vp-c-text-2);
  border-bottom: 1px solid var(--vp-c-divider);
}

.header-title {
  flex: 1;
  min-width: 0;
}

.header-created,
.header-modified {
  width: 145px;
  text-align: right;
  flex-shrink: 0;
}

.header-created {
  margin-right: 16px;
}

.sortable {
  cursor: pointer;
  user-select: none;
  transition: color 0.2s ease;
}

.sortable:hover {
  color: var(--vp-c-brand-1);
}

.sort-icon {
  display: inline-block;
  width: 12px;
  margin-left: 2px;
  color: var(--vp-c-brand-1);
}

.article-item {
  display: flex;
  align-items: center;
  padding: 12px 0;
  border-bottom: 1px dashed var(--vp-c-divider);
  text-decoration: none;
  transition: all 0.2s ease;
}

.article-item:last-child {
  border-bottom: none;
}

.article-item:hover {
  color: var(--vp-c-brand-1);
}

.article-item:hover .article-title {
  color: var(--vp-c-brand-1);
}

.article-title {
  font-size: 14px;
  color: var(--vp-c-text-1);
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-right: 16px;
  transition: color 0.2s ease;
}

.article-created,
.article-modified {
  width: 145px;
  font-size: 12px;
  color: var(--vp-c-text-3);
  text-align: right;
  flex-shrink: 0;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas,
    "Liberation Mono", monospace;
}

.article-created {
  margin-right: 16px;
}

.no-articles {
  text-align: center;
  color: var(--vp-c-text-3);
  padding: 40px;
  background: var(--vp-c-bg-soft);
  border-radius: 12px;
}

@media (max-width: 640px) {
  .category-page {
    padding: 16px;
  }

  .category-title {
    font-size: 24px;
  }

  .article-header {
    display: none;
  }

  .article-item {
    flex-wrap: wrap;
    gap: 4px;
  }

  .article-title {
    width: 100%;
    margin-right: 0;
  }

  .article-created,
  .article-modified {
    width: auto;
    text-align: left;
  }

  .article-created {
    margin-right: 8px;
  }

  .article-created::after {
    content: " 发布";
    color: var(--vp-c-text-3);
  }

  .article-modified::after {
    content: " 修改";
    color: var(--vp-c-text-3);
  }
}
</style>
