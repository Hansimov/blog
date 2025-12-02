<script setup lang="ts">
import { computed } from "vue";
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
      <h3 class="section-title">📅 最新发布</h3>
      <div class="article-header">
        <span class="header-title">标题</span>
        <span class="header-date">发布时间</span>
      </div>
      <ul class="article-list">
        <li
          v-for="article in recentlyCreated"
          :key="article.url"
          class="article-item"
        >
          <a :href="article.url" class="article-link">
            <span class="article-title">{{ article.title }}</span>
            <span class="article-date">{{ formatDate(article.created) }}</span>
          </a>
        </li>
      </ul>
    </div>

    <div class="articles-section">
      <h3 class="section-title">🔄 最近修改</h3>
      <div class="article-header">
        <span class="header-title">标题</span>
        <span class="header-date">修改时间</span>
      </div>
      <ul class="article-list">
        <li
          v-for="article in recentlyModified"
          :key="article.url"
          class="article-item"
        >
          <a :href="article.url" class="article-link">
            <span class="article-title">{{ article.title }}</span>
            <span class="article-date">{{ formatDate(article.modified) }}</span>
          </a>
        </li>
      </ul>
    </div>
  </div>
</template>

<style scoped>
.recent-articles {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 40px;
  max-width: 900px;
  margin: 20px auto;
  padding: 0 20px;
}

@media (max-width: 768px) {
  .recent-articles {
    grid-template-columns: 1fr;
    gap: 30px;
  }
}

.articles-section {
  background: var(--vp-c-bg-soft);
  border-radius: 12px;
  padding: 20px 24px;
}

.section-title {
  font-size: 20px;
  font-weight: 600;
  margin: 0 0 12px 0;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--vp-c-divider);
  color: var(--vp-c-text-1);
}

.article-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  margin-bottom: 4px;
  font-size: 13px;
  font-weight: 600;
  color: var(--vp-c-text-2);
}

.header-title {
  flex: 1;
}

.header-date {
  flex-shrink: 0;
}

.article-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.article-item {
  margin: 0;
  padding: 0;
}

.article-link {
  display: flex;
  justify-content: space-between;
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
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  margin-right: 12px;
  transition: color 0.2s ease;
}

.article-date {
  font-size: 12px;
  color: var(--vp-c-text-3);
  flex-shrink: 0;
}
</style>
