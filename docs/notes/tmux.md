# 安装 tmux

```sh
sudo apt install tmux
cd ~
touch .tmux.conf
```

## 常用命令

```sh
tmux new -s <session_id>
```

连接到指定 session：

```sh
tmux attach -d -t <session_id>
```

连接到最近的 session：

```sh
tmux attach
```

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/.tmux.conf
:::
<<< @/notes/configs/.tmux.conf