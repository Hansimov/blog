<script setup lang="ts">
import { computed } from "vue";
import { withBase } from "vitepress";
// @ts-ignore
import { data as articlesData } from "../../../articles.data.mjs";

const recentlyCreated = computed(() => {
  return [...articlesData].sort((a, b) => b.created - a.created).slice(0, 10);
});

const recentlyModified = computed(() => {
  return [...articlesData].sort((a, b) => b.modified - a.modified).slice(0, 10);
});

function formatDate(timestamp: number): string {
  const date = new Date(timestamp);
  const pad = (n: number) => n.toString().padStart(2, "0");
  return `${date.getFullYear()}/${pad(date.getMonth() + 1)}/${pad(
    date.getDate()
  )} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(
    date.getSeconds()
  )}`;
}
</script>

<template>
  <div class="recent-articles">
    <div class="articles-section">
      <h3 class="section-title">最新发布</h3>
      <div class="article-header">
        <span class="header-title">标题</span>
        <span class="header-category">分类</span>
        <span class="header-date">发布时间</span>
      </div>
      <ul class="article-list">
        <li
          v-for="article in recentlyCreated"
          :key="article.url"
          class="article-item"
        >
          <a :href="withBase(article.url)" class="article-link">
            <span class="article-title" :title="article.title">{{
              article.title
            }}</span>
            <span class="article-category">{{ article.category }}</span>
            <span class="article-date">{{ formatDate(article.created) }}</span>
          </a>
        </li>
      </ul>
    </div>

    <div class="articles-section">
      <h3 class="section-title">最近修改</h3>
      <div class="article-header">
        <span class="header-title">标题</span>
        <span class="header-category">分类</span>
        <span class="header-date">修改时间</span>
      </div>
      <ul class="article-list">
        <li
          v-for="article in recentlyModified"
          :key="article.url"
          class="article-item"
        >
          <a :href="withBase(article.url)" class="article-link">
            <span class="article-title" :title="article.title">{{
              article.title
            }}</span>
            <span class="article-category">{{ article.category }}</span>
            <span class="article-date">{{ formatDate(article.modified) }}</span>
          </a>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.recent-articles {
  display: flex;
  justify-content: center;
  gap: 30px;
  max-width: 100%;
  padding: 0 20px 20px;
  box-sizing: border-box;
}

@media (max-width: 768px) {
  .recent-articles {
    flex-direction: column;
    align-items: center;
    gap: 24px;
  }
}

.articles-section {
  background: var(--vp-c-bg-soft);
  border-radius: 12px;
  padding: 20px 24px;
  width: 560px;
  max-width: calc(50% - 15px);
}

@media (max-width: 768px) {
  .articles-section {
    width: 100%;
    max-width: 500px;
  }
}

.section-title {
  flex-shrink: 0;
  font-size: 18px;
  font-weight: 600;
  margin: 0 0 16px 0;
  padding-bottom: 12px;
  border-bottom: 2px solid var(--vp-c-brand-1);
  color: var(--vp-c-text-1);
}

.article-header {
  display: flex;
  align-items: center;
  padding: 8px 0;
  margin-bottom: 4px;
  font-size: 12px;
  font-weight: 600;
  color: var(--vp-c-text-2);
  flex-shrink: 0;
}

.header-title {
  flex: 1;
  min-width: 0;
}

.header-category {
  width: 70px;
  text-align: center;
  flex-shrink: 0;
}

.header-date {
  width: 145px;
  text-align: right;
  flex-shrink: 0;
}

.article-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.article-list::-webkit-scrollbar {
  width: 6px;
}

.article-list::-webkit-scrollbar-track {
  background: transparent;
}

.article-list::-webkit-scrollbar-thumb {
  background: var(--vp-c-divider);
  border-radius: 3px;
}

.article-list::-webkit-scrollbar-thumb:hover {
  background: var(--vp-c-text-3);
}

.article-item {
  margin: 0;
  padding: 0;
}

.article-link {
  display: flex;
  align-items: center;
  padding: 10px 0;
  border-bottom: 1px dashed var(--vp-c-divider);
  text-decoration: none;
  transition: all 0.2s ease;
}

.article-item:last-child .article-link {
  border-bottom: none;
}

.article-link:hover {
  color: var(--vp-c-brand-1);
}

.article-link:hover .article-title {
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
  margin-right: 8px;
  transition: color 0.2s ease;
}

.article-category {
  width: 70px;
  font-size: 11px;
  color: var(--vp-c-text-2);
  text-align: center;
  flex-shrink: 0;
  background: var(--vp-c-default-soft);
  padding: 2px 8px;
  border-radius: 4px;
  margin-right: 8px;
}

.article-date {
  width: 145px;
  font-size: 12px;
  color: var(--vp-c-text-3);
  text-align: right;
  flex-shrink: 0;
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas,
    "Liberation Mono", monospace;
}
</style>
