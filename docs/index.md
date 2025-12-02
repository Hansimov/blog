---
# https://vitepress.dev/reference/default-theme-home-page
# https://github.com/vuejs/vitepress/blob/main/docs/index.md?plain=1
layout: home

# hero:
  # name: "Hansimov"
  # text: "Software and AI"
  # tagline: It's never too late. Just do it better.
  # actions:
  #   - theme: brand
  #     text: Notes
  #     link: /notes/vitepress-init

---

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import RecentArticles from './.vitepress/theme/components/RecentArticles.vue'
import CategoryNav from './.vitepress/theme/components/CategoryNav.vue'

const showHeader = ref(true)
const heightThreshold = 600
const widthThreshold = 768

function checkSize() {
  showHeader.value = window.innerHeight >= heightThreshold && window.innerWidth >= widthThreshold
}

onMounted(() => {
  checkSize()
  window.addEventListener('resize', checkSize)
})

onUnmounted(() => {
  window.removeEventListener('resize', checkSize)
})
</script>

<div v-if="showHeader" class="hero-section">
  <p class="tagline">It's never too late. Just do it better.</p>
</div>

<!-- <img class="ghchart" src="https://ghchart.rshah.org/Hansimov" alt="GitHub Contributions"> -->

<CategoryNav v-if="showHeader" />

<RecentArticles />

<style>
.hero-section {
  display: flex;
  justify-content: center;
  padding: 30px 20px 5px;
  flex-shrink: 0;
}

.tagline {
  font-size: 32px;
  font-weight: bold;
  color: var(--vp-c-text-2);
  margin: 0;
  text-align: center;
}

@media (max-width: 640px) {
  .tagline {
    font-size: 24px;
  }
}
</style>


