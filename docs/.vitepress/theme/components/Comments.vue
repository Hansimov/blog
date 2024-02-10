<script setup lang="ts">
import { useData } from "vitepress";

const { frontmatter, title } = useData();
</script>

<template>
    <div v-if="frontmatter.comments !== false" :key="title" class="giscus">
        <component
            :is="'script'"
            src="https://giscus.app/client.js"
            data-repo="Hansimov/blog"
            data-repo-id="R_kgDOLQOGCA"
            data-category="Blog Comments"
            data-category-id="DIC_kwDOLQOGCM4CdHfm"
            data-mapping="pathname"
            data-strict="0"
            data-reactions-enabled="0"
            data-emit-metadata="0"
            data-input-position="bottom"
            data-theme="light"
            data-lang="en"
            crossorigin="anonymous"
            async
        />
    </div>
</template>
