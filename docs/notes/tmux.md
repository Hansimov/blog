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

保存最近 N 行输出到本地文件：

```sh
tmux capture-pane -p -J -S -100 > ./tmux_stdout.log
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


## 安装插件管理器 tpm

::: tip Tmux Plugin Manager
  * https://github.com/tmux-plugins/tpm

A list of tmux plugins.
* https://github.com/tmux-plugins/list
:::


下载代码仓库：

```sh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

在 `.tmux.conf` 末尾添加：

```sh
# List of plugins
set -g @plugin 'tmux-plugins/tpm'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
```

重新加载配置：

```sh
# type this in terminal if tmux is already running
tmux source ~/.tmux.conf
```

## 安装会话恢复插件 tmux-resurrect

::: tip tmux-resurrect: Persists tmux environment across system restarts.
* https://github.com/tmux-plugins/tmux-resurrect

Restoring programs
* https://github.com/tmux-plugins/tmux-resurrect/blob/master/docs/restoring_programs.md

Undo the last session saved with Tmux Resurrect | by Pasindu Rumal Perera | Medium
* https://medium.com/%40udnisap/restore-older-sessions-in-tmux-resurrect-8892629ef004
:::

### 安装插件

首先确保已经安装了 tpm 插件管理器。

在 `.tmux.conf` 的插件列表中添加：

```sh
# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'
```

按下插件管理器的安装快捷键：`ctrl+b` + `I`。
等待一会，安装完成会提示按下 `Esc` 退出。

### 恢复程序

可以通过 `.tmux.conf` 中的 `set -g @resurrect-processes '...'` 命令来指定。不同程序之间用空格分隔。

- 插件默认恢复的程序：
  ```sh
  vi vim nvim emacs man less more tail top htop irssi weechat mutt
  ```
- 指定额外恢复的程序：
  ```sh
   set -g @resurrect-processes 'ssh psql mongosh elasticsearch'
  ```
- 带参数的程序需加上双引号：
  ```sh
  set -g @resurrect-processes "kibana serve --host 0.0.0.0 --port 5601"
  ```
- 不恢复任何程序：
  ```sh
  set -g @resurrect-processes 'false'
  ```
- 恢复所有程序：<m>（危险！不建议使用！）</m>
  ```sh
  set -g @resurrect-processes 'true:all'
  ```

### 保存和恢复会话

快捷键：

- 保存：`ctrl+b` + `ctrl+s`
- 恢复：`ctrl+b` + `ctrl+r`

会话默认保存在：
- `~/.tmux/resurrect/`
- `~/.local/share/tmux/resurrect/`

查看保存的会话：

```sh
ls -l ~/.local/share/tmux/resurrect
```

输出形如：

```sh
lrwxrwxrwx 1 user user   34  7月 28 06:31 last -> tmux_resurrect_20250728T063124.txt
-rw-rw-r-- 1 user user 8172  6月  5 09:07 tmux_resurrect_20250605T090739.txt
-rw-rw-r-- 1 user user 9076  7月  8 05:41 tmux_resurrect_20250708T054126.txt
-rw-rw-r-- 1 user user 8627  7月 21 15:25 tmux_resurrect_20250721T152506.txt
-rw-rw-r-- 1 user user 8708  7月 24 04:22 tmux_resurrect_20250724T042208.txt
-rw-rw-r-- 1 user user 9329  7月 28 06:31 tmux_resurrect_20250728T063124.txt
```

将 last 对应的 txt 复制到 `~/downloads` 中：

```sh
cp ~/.local/share/tmux/resurrect/last ~/downloads/tmux_resurrect_last.txt
```

将 last 软链接到其他 txt：

```sh
ln -s ~/.local/share/tmux/resurrect/tmux_resurrect_XXXX.txt ~/.local/share/tmux/resurrect/last
```

### 配置示例

```sh
# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-resurrect'

# Restore programs
set -g @resurrect-processes '\
    ssh psql mongosh \
    "~elasticsearch->elasticsearch *" \
    "~kibana serve->kibana serve *" \
    "~python->python *" \
    "~quasar dev->quasar dev *" \
    "~./frpc->./frpc *" \
    "~docker->docker *" \
'

# Initialize TMUX plugin manager (keep this line at the very bottom of tmux.conf)
run '~/.tmux/plugins/tpm/tpm'
```