<script setup lang="ts">
import { computed } from "vue";
import { withBase } from "vitepress";
// @ts-ignore
import { data as articlesData } from "../../../articles.data.mjs";

const categories = [
  { name: "Networks", link: "/notes/frp-proxy" },
  { name: "Tools", link: "/notes/remote-ssh" },
  { name: "Softwares", link: "/notes/conda" },
  { name: "Databases", link: "/notes/postgresql" },
  { name: "Workflows", link: "/notes/vitepress-init" },
  { name: "Ubuntu", link: "/notes/ubuntu-config" },
  { name: "LLMs", link: "/notes/llama-cpp" },
  { name: "Configs", link: "/notes/bash-aliases" },
];

const articlesByCategory = computed(() => {
  const grouped: Record<string, typeof articlesData> = {};
  for (const cat of categories) {
    grouped[cat.name] = articlesData.filter(
      (article: any) => article.category === cat.name
    );
  }
  return grouped;
});
</script>

<template>
  <div class="categories">
    <div v-for="cat in categories" :key="cat.name" class="category-wrapper">
      <a :href="withBase(cat.link)" class="category-link">{{ cat.name }}</a>
      <div class="dropdown">
        <a
          v-for="article in articlesByCategory[cat.name]"
          :key="article.url"
          :href="withBase(article.url)"
          class="dropdown-item"
          :title="article.title"
        >
          {{ article.title }}
        </a>
        <div
          v-if="articlesByCategory[cat.name]?.length === 0"
          class="dropdown-empty"
        >
          暂无文章
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.categories {
  display: flex;
  justify-content: center;
  flex-wrap: nowrap;
  gap: 12px;
  padding: 15px 20px 20px;
  margin: 0 auto;
  flex-shrink: 0;
}

.category-wrapper {
  position: relative;
}

.category-link {
  display: inline-block;
  padding: 8px 20px;
  background: var(--vp-c-bg-soft);
  color: var(--vp-c-text-1);
  border-radius: 20px;
  text-decoration: none;
  font-size: 15px;
  font-weight: 500;
  transition: all 0.2s ease;
  border: 1px solid var(--vp-c-divider);
}

.category-wrapper:hover .category-link {
  background: var(--vp-c-brand-soft);
  color: var(--vp-c-brand-1);
  border-color: var(--vp-c-brand-1);
  transform: translateY(-2px);
}

.dropdown {
  position: absolute;
  top: 100%;
  left: 50%;
  transform: translateX(-50%);
  min-width: 240px;
  max-width: 320px;
  max-height: 400px;
  overflow-y: auto;
  background: var(--vp-c-bg-elv);
  border: 1px solid var(--vp-c-divider);
  border-radius: 8px;
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.1);
  padding: 8px 0;
  margin-top: 8px;
  opacity: 0;
  visibility: hidden;
  transition: all 0.2s ease;
  z-index: 100;
}

.category-wrapper:hover .dropdown {
  opacity: 1;
  visibility: visible;
}

.dropdown-item {
  display: block;
  padding: 8px 16px;
  color: var(--vp-c-text-1);
  text-decoration: none;
  font-size: 13px;
  line-height: 1.4;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  transition: all 0.15s ease;
}

.dropdown-item:hover {
  background: var(--vp-c-brand-soft);
  color: var(--vp-c-brand-1);
}

.dropdown-empty {
  padding: 12px 16px;
  color: var(--vp-c-text-3);
  font-size: 13px;
  text-align: center;
}

@media (max-width: 640px) {
  .categories {
    flex-wrap: wrap;
    gap: 8px;
  }

  .category-link {
    padding: 6px 14px;
    font-size: 14px;
  }

  .dropdown {
    min-width: 200px;
    max-width: 280px;
    left: 0;
    transform: none;
  }
}
</style>
