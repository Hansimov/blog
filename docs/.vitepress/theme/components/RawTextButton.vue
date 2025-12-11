<template>
  <Teleport v-if="showButton && searchTarget" :to="searchTarget">
    <div class="raw-text-button-wrapper">
      <button
        class="raw-text-button"
        @click="toggleRawText"
        :title="isShowingRaw ? '返回渲染视图' : '查看纯文本'"
      >
        <svg
          v-if="!isShowingRaw"
          xmlns="http://www.w3.org/2000/svg"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <polyline points="4 17 10 11 4 5"></polyline>
          <line x1="12" y1="19" x2="20" y2="19"></line>
        </svg>
        <svg
          v-else
          xmlns="http://www.w3.org/2000/svg"
          width="20"
          height="20"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
          <circle cx="12" cy="12" r="3"></circle>
        </svg>
      </button>
    </div>
  </Teleport>

  <Teleport to="body">
    <div v-if="isShowingRaw" class="raw-text-overlay" @click="closeRawText">
      <div class="raw-text-container" @click.stop>
        <div class="raw-text-header">
          <h3>{{ currentTitle }}</h3>
          <button class="close-button" @click="closeRawText" title="关闭">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="24"
              height="24"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            >
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </div>
        <pre class="raw-text-content">{{ rawContent }}</pre>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch, nextTick } from "vue";
import { useData, useRoute, withBase } from "vitepress";

const { page } = useData();
const route = useRoute();

const isShowingRaw = ref(false);
const rawContent = ref("");
const currentTitle = ref("");
const searchTarget = ref<HTMLElement | null>(null);
let navObserver: MutationObserver | null = null;

// 只在文章页面显示按钮（不在首页和分类页面）
const showButton = computed(() => {
  const relPath = page.value?.relativePath || "";
  return relPath.startsWith("notes/") || relPath.startsWith("research/");
});

const markdownUrl = computed(() => {
  const relPath = page.value?.relativePath;
  if (relPath) {
    return withBase(`/${relPath}`);
  }
  return route.path.replace(/\.html$/, ".md");
});

async function fetchRawContent() {
  try {
    // 从当前路径构建 .md 文件路径
    const response = await fetch(markdownUrl.value);
    if (response.ok) {
      rawContent.value = await response.text();
      // 从内容中提取标题
      const titleMatch = rawContent.value.match(/^#\s+(.+)$/m);
      currentTitle.value = titleMatch ? titleMatch[1] : "文章内容";
    } else {
      rawContent.value = "无法加载文章内容";
      currentTitle.value = "错误";
    }
  } catch (error) {
    rawContent.value = "加载失败: " + error;
    currentTitle.value = "错误";
  }
}

function toggleRawText() {
  if (!isShowingRaw.value) {
    fetchRawContent();
  }
  isShowingRaw.value = !isShowingRaw.value;
}

function closeRawText() {
  isShowingRaw.value = false;
}

// ESC 键关闭
const handleEsc = (e: KeyboardEvent) => {
  if (e.key === "Escape" && isShowingRaw.value) {
    closeRawText();
  }
};

onMounted(() => {
  document.addEventListener("keydown", handleEsc);
  updateSearchTarget();
  if (typeof MutationObserver !== "undefined") {
    navObserver = new MutationObserver(updateSearchTarget);
    navObserver.observe(document.body, { childList: true, subtree: true });
  }
});

onUnmounted(() => {
  document.removeEventListener("keydown", handleEsc);
  setNavMode(false);
  navObserver?.disconnect();
  navObserver = null;
});

// 路由变化时关闭弹窗
watch(
  () => route.path,
  () => {
    isShowingRaw.value = false;
  }
);

function setNavMode(active: boolean) {
  if (typeof document === "undefined") return;
  document.documentElement.classList.toggle("raw-text-mode", active);
}

watch(
  showButton,
  (visible) => {
    setNavMode(visible);
    if (visible) {
      nextTick(updateSearchTarget);
    }
    if (!visible) {
      isShowingRaw.value = false;
    }
  },
  { immediate: true }
);

function updateSearchTarget() {
  if (typeof document === "undefined") return;
  searchTarget.value = document.querySelector<HTMLElement>(".VPNavBarSearch");
}
</script>

<style scoped>
.raw-text-button-wrapper {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 40px;
  margin-left: 0.5rem;
}

.raw-text-button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--vp-c-text-2);
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.25s;
}

.raw-text-button:hover {
  background: var(--vp-c-bg-soft);
  color: var(--vp-c-text-1);
}

@media (max-width: 768px) {
  .raw-text-button-wrapper {
    display: none;
  }
}

.raw-text-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.75);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10000;
  padding: 20px;
}

.raw-text-container {
  background: var(--vp-c-bg);
  border-radius: 8px;
  max-width: 900px;
  width: 100%;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
}

.raw-text-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 24px;
  border-bottom: 1px solid var(--vp-c-divider);
}

.raw-text-header h3 {
  margin: 0;
  font-size: 18px;
  color: var(--vp-c-text-1);
}

.close-button {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  padding: 0;
  border: none;
  background: transparent;
  color: var(--vp-c-text-2);
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.25s;
}

.close-button:hover {
  background: var(--vp-c-bg-soft);
  color: var(--vp-c-text-1);
}

.raw-text-content {
  flex: 1;
  overflow: auto;
  padding: 24px;
  margin: 0;
  font-family: "Consolas", "Monaco", "Courier New", monospace;
  font-size: 14px;
  line-height: 1.6;
  white-space: pre-wrap;
  word-break: break-word;
  color: var(--vp-c-text-1);
  background: var(--vp-c-bg-soft);
}

/* 滚动条样式 */
.raw-text-content::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

.raw-text-content::-webkit-scrollbar-track {
  background: var(--vp-c-bg);
}

.raw-text-content::-webkit-scrollbar-thumb {
  background: var(--vp-c-divider);
  border-radius: 4px;
}

.raw-text-content::-webkit-scrollbar-thumb:hover {
  background: var(--vp-c-text-3);
}
</style>
