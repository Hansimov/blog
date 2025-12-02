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

<div align="center" style="font-size:40px; font-weight:bold; line-height:40px; padding:50px 0px 50px 0px; color:gray;">
It's never too late. Just do it better.
</div>

<div align="center">
  <img style="width:800px; max-width:95vw;" src="https://ghchart.rshah.org/Hansimov">
</div>

<hr>

<RecentArticles />

<hr>

<div align="center" style="font-size:25px; line-height:35px;">

<b>Tech Notes</b>

<a href="./notes/frp-proxy"><u>Networks</u></a>
 · <a href="./notes/remote-ssh"><u>Tools</u></a>
 · <a href="./notes/conda"><u>Softwares</u></a>
 · <a href="./notes/postgresql"><u>Databases</u></a>
 · <a href="./notes/vitepress-init"><u>Workflows</u></a>
 · <a href="./notes/ubuntu-config"><u>Ubuntu</u></a>
 · <a href="./notes/llama-cpp"><u>LLMs</u></a>
 · <a href="./notes/bash-aliases"><u>Configs</u></a> 
</div>


