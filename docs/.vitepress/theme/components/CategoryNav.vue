<script setup lang="ts">
import { ref, computed } from "vue";
import { withBase } from "vitepress";
// @ts-ignore
import { data as articlesData } from "../../../articles.data.mjs";
// @ts-ignore
import { categoryItems } from "../../categories";

const categories = categoryItems.map((item: { text: string }) => item.text);

const articlesByCategory = computed(() => {
  const grouped: Record<string, typeof articlesData> = {};
  for (const cat of categories) {
    grouped[cat] = articlesData.filter(
      (article: any) => article.category === cat
    );
  }
  return grouped;
});

function getCategoryLink(name: string): string {
  return `/categories/${name.toLowerCase()}`;
}

// 用于延迟展开/收起的状态管理
const hoveredCategory = ref<string | null>(null);
const showDropdown = ref<string | null>(null);
let hoverTimeout: ReturnType<typeof setTimeout> | null = null;
let leaveTimeout: ReturnType<typeof setTimeout> | null = null;

function handleMouseEnter(catName: string) {
  // 清除离开定时器
  if (leaveTimeout) {
    clearTimeout(leaveTimeout);
    leaveTimeout = null;
  }
  hoveredCategory.value = catName;
  // 延迟展开
  hoverTimeout = setTimeout(() => {
    showDropdown.value = catName;
  }, 150);
}

function handleMouseLeave() {
  // 清除进入定时器
  if (hoverTimeout) {
    clearTimeout(hoverTimeout);
    hoverTimeout = null;
  }
  hoveredCategory.value = null;
  // 延迟收起
  leaveTimeout = setTimeout(() => {
    showDropdown.value = null;
  }, 200);
}
</script>

<template>
  <div class="categories">
    <div
      v-for="cat in categories"
      :key="cat"
      class="category-wrapper"
      @mouseenter="handleMouseEnter(cat)"
      @mouseleave="handleMouseLeave"
    >
      <a
        :href="withBase(getCategoryLink(cat))"
        class="category-link"
        :class="{ active: hoveredCategory === cat }"
        >{{ cat }}</a
      >
      <transition name="dropdown-fade">
        <div v-show="showDropdown === cat" class="dropdown">
          <a
            v-for="article in articlesByCategory[cat]"
            :key="article.url"
            :href="withBase(article.url)"
            class="dropdown-item"
            :title="article.title"
          >
            {{ article.title }}
          </a>
          <div
            v-if="articlesByCategory[cat]?.length === 0"
            class="dropdown-empty"
          >
            暂无文章
          </div>
        </div>
      </transition>
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
  transition: all 0.3s ease;
  border: 1px solid var(--vp-c-divider);
}

.category-link.active,
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
  z-index: 100;
}

/* 下拉菜单过渡动画 */
.dropdown-fade-enter-active,
.dropdown-fade-leave-active {
  transition: opacity 0.25s ease, transform 0.25s ease;
}

.dropdown-fade-enter-from,
.dropdown-fade-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(-8px);
}

.dropdown-fade-enter-to,
.dropdown-fade-leave-from {
  opacity: 1;
  transform: translateX(-50%) translateY(0);
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

  .dropdown-fade-enter-from,
  .dropdown-fade-leave-to {
    transform: translateY(-8px);
  }

  .dropdown-fade-enter-to,
  .dropdown-fade-leave-from {
    transform: translateY(0);
  }
}
</style>
