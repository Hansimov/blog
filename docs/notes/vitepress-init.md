# 使用 VitePress

## 前置要求

参考：[安装 node.js 和 npm](/notes/nodejs.md)

## 配置 vitepress
::: tip See: https://vitepress.dev/guide/getting-started
:::

```sh
npm add -D vitepress
npx vitepress init
```

选择如下选项：

```sh{4,7,10,13}
┌  Welcome to VitePress!
│
◇  Where should VitePress initialize the config?
│  ./docs
│
◇  Site title:
│  Hansimov's Blog
│
◇  Site description:
│  A VitePress Site
│
◆  Theme:
│  ● Default Theme (Out of the box, good-looking docs)
│  ○ Default Theme + Customization
│  ○ Custom Theme
└
```

### dev
```sh
npx vitepress dev docs --host 0.0.0.0 --port 15173
# default dev port is 5173
```

### 常见问题

在 Linux 下运行上一行有可能出现如下错误：

```sh
Error: ENOSPC: System limit for number of file watchers reached, watch '~/repos/blog/docs/.vitepress/config.mts'
```

可以修改：

```sh
sudo nano /etc/sysctl.conf
```

在文件末尾添加：

```sh
fs.inotify.max_user_watches = 524288
```

重启 sysctl 生效：

```sh
sudo sysctl -p
```

查看 max_user_wathes:

```sh
cat /proc/sys/fs/inotify/max_user_watches
```

输出应为：

```sh
524288
```

::: tip watchman - React Native Error: ENOSPC: System limit for number of file watchers reached - Stack Overflow
* https://stackoverflow.com/questions/55763428/react-native-error-enospc-system-limit-for-number-of-file-watchers-reached
:::

### build 和 preview

::: tip See: https://vitepress.dev/guide
:::

```sh
npx vitepress build docs
npx vitepress preview docs --host 0.0.0.0
# Can also put --host arg in `package.json` > "scripts"
# default preview port is 4173
```

### 自定义 public base path

::: tip See: https://vitepress.dev/reference/site-config#base
:::

If blog site is in a subdomain `/blog/`, which would be like `https://hansimov.github.io/blog`, then following line should be added in `docs/.vitepress/config.mts`:

```ts{4}
export default defineConfig({
  title: "Hansimov's Blog",
  description: "Software and AI",
  base: "/blog/",
  themeConfig: {
    ...
})
```

## 部署 GitHub Pages

::: tip See: https://vitepress.dev/guide/deploy#github-pages
:::

Create a file named `deploy.yml` inside `.github/workflows`, and put these lines.

See: https://github.com/Hansimov/blog/tree/main/.github/workflows/deploy.yml

- Make sure the `base` option in VitePress is properly configured before deploying.

- Also, the node version config in .yml should be consistant with the local dev environment.

- Do not git ignore `package-lock.json`, as it is required for the GitHub Actions to install the dependencies.

In repo webpage, go to **Settings** > **Pages** > **Build and deployment** > **Source**, select __GitHub Actions__.

Then push changes to main branch, and the site would be built and available at https://hansimov.github.io/blog.