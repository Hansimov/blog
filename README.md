# Hansimov's Blog

## Initialize and setup

### Install Node.js and npm
```bash
sudo apt update
sudo apt install nodejs
# node -v
sudo apt install npm
# npm -v
```


### Upgrade node.js to 18 with nvm
```sh
wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# bash
# nvm -v
# NOTE: `which nvm` would output nothing, but `nvm` is indeed available in the current shell
nvm install 18.16.0
```

### Setup vitepress
See: https://vitepress.dev/guide/getting-started

```sh
npm add -D vitepress
npx vitepress init
```

Select following options:

```sh
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

### Dev
```sh
npx vitepress dev docs --host 0.0.0.0
# default dev port is 5173
```

### Build and preview

See: https://vitepress.dev/guide/deploy

```sh
npx vitepress build docs
npx vitepress preview docs --host 0.0.0.0
# Can also put --host arg in `package.json` > "scripts"
# default preview port is 4173
```

### Customize public base path

See: https://vitepress.dev/reference/site-config#base

If blog site is in a subdomain `/blog/`, which would be like `https://hansimov.github.io/blog`, then following line should be added in `docs/.vitepress/config.mts`:

```sh
    base: "/blog/",
```
