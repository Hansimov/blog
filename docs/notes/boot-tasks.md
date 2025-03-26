# 服务器断电重启任务恢复

## 恢复 tmux 进程

tmux 配置可参考：[tmux-安装会话恢复插件](tmux.html#安装会话恢复插件-tmux-resurrect)

```sh
tmux new -s y
```

键入 `alt+z` + `ctrl+r`，恢复所有 tmux 的会话。

键入 `alt+z` + `w`，找到会话 `y`，回车，键入 `alt+z` + `x` + `y`，关闭该会话，只保留恢复的会话。

键入 `ta` 重新进入 tmux。

## 检查依赖 elastic 的服务

由于 elastic 启动较慢，需要查看依赖 elastic 的服务是否正常运行。

可能需要重启 bili-search 的 docker 和 local-dev 服务。

## 恢复 docker 容器

```sh
docker compose build && docker compose down && docker compose up
```

## 恢复网络路由

```sh
cd ~/repos/bili-scraper
sudo env "PATH=$PATH" python -m networks.ipv6.router
```