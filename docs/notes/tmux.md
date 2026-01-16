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

## 开机自动启动 tmux 会话

### 清理临时会话

```sh
nano ~/.tmux.conf
```

添加：

```sh
set -g @resurrect-hook-pre-restore-pane-processes 'tmux kill-session -t=0 2>/dev/null || true'
```

### 创建 systemd 服务

设置无须登录即可启动：

```sh
sudo loginctl enable-linger "$USER"
```
```sh
# show user linger status
# loginctl show-user "$USER" -p Linger

# disable linger
# sudo loginctl disable-linger "$USER"
```

创建 systemd 服务文件：

```sh
nano ~/.config/systemd/user/tmux-restore.service
```

添加如下内容：

```sh
[Unit]
Description=Restore tmux sessions with tmux-resurrect
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
# run tmux server (with temp session)
ExecStart=/bin/sh -lc '/usr/bin/tmux has-session 2>/dev/null || /usr/bin/tmux new-session -d'
# run store shell
ExecStart=/usr/bin/tmux run-shell %h/.tmux/plugins/tmux-resurrect/scripts/restore.sh
# [Optional] save tmux sessions on stop
ExecStop=/usr/bin/tmux run-shell %h/.tmux/plugins/tmux-resurrect/scripts/save.sh

[Install]
WantedBy=default.target
```

重启服务守护进程：

```sh
systemctl --user daemon-reload
```

启用服务：

```sh
systemctl --user enable tmux-restore.service
```

### 查看服务状态

```sh
systemctl --user status tmux-restore
```

### 查看服务日志

```sh
journalctl --user -u tmux-restore.service -b --no-pager | tail -20
```

### 【备用】手动启动

如果想直接手动启动 tmux 并恢复会话，可以运行：

```sh
tmux attach || (tmux new-session -d && tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && tmux attach)
```