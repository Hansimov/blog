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
import RecentArticles from './.vitepress/theme/components/RecentArticles.vue'
</script>

<div class="hero-section">
  <p class="tagline">It's never too late. Just do it better.</p>
</div>

<!-- <img class="ghchart" src="https://ghchart.rshah.org/Hansimov" alt="GitHub Contributions"> -->

<div class="categories">
  <a href="./notes/frp-proxy" class="category-link">Networks</a>
  <a href="./notes/remote-ssh" class="category-link">Tools</a>
  <a href="./notes/conda" class="category-link">Softwares</a>
  <a href="./notes/postgresql" class="category-link">Databases</a>
  <a href="./notes/vitepress-init" class="category-link">Workflows</a>
  <a href="./notes/ubuntu-config" class="category-link">Ubuntu</a>
  <a href="./notes/llama-cpp" class="category-link">LLMs</a>
  <a href="./notes/bash-aliases" class="category-link">Configs</a>
</div>

<RecentArticles />

<style>
.hero-section {
  display: flex;
  justify-content: center;
  padding: 40px 20px 20px;
}

.tagline {
  font-size: 32px;
  font-weight: bold;
  color: var(--vp-c-text-2);
  margin: 0;
  text-align: center;
}

.categories {
  display: flex;
  justify-content: center;
  flex-wrap: nowrap;
  gap: 12px;
  padding: 0 20px 30px;
  margin: 0 auto;
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

.category-link:hover {
  background: var(--vp-c-brand-soft);
  color: var(--vp-c-brand-1);
  border-color: var(--vp-c-brand-1);
  transform: translateY(-2px);
}

@media (max-width: 640px) {
  .tagline {
    font-size: 24px;
  }
  
  .categories {
    flex-wrap: wrap;
    gap: 8px;
  }
  
  .category-link {
    padding: 6px 14px;
    font-size: 14px;
  }
}
</style>


