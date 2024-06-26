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


## 一键配置

```sh
cp ~/.tmux.conf ~/.tmux.conf.bak
```

```sh
wget https://raw.githubusercontent.com/Hansimov/blog/main/docs/notes/configs/.tmux.conf -O ~/.tmux.conf && tmux source ~/.tmux.conf
```

## .tmux.conf 完整样例

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/.tmux.conf
:::
<<< @/notes/configs/.tmux.conf