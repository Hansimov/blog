# 远程网络中转

## 背景

机器信息：
- 个人电脑 P
- 远程服务器 X
- 另一台服务器 A

需求：在 P 上，通过 X 作为中转，让 P -> A 的网络连接和请求，都经过 X 转发：
- VSCode Remote SSH
- MobaXterm

## VSCode Remote SSH

在 P 机器上，编辑 SSH 配置文件：
- `C:\Users\<用户名>\.ssh\config`

添加如下配置：

```ssh
Host x
  HostName x
  User <X的用户名>

Host a-delay
  HostName a
  User <A的用户名>
  ProxyJump x

Host a
  HostName a
  User <A的用户名>
```

之后，在 VSCode Remote SSH 中连接 `a-delay` 即可通过 X 作为中转连接到 A。

## MobaXterm

在 MobaXterm 中：
- 右键 A 的 session，选择 "Edit session"
- 选择 "Network settings" 选项卡
- 点击 "SSH gateway (jump host)"
  - Gateway host: `x`
  - Gateway user: `<X的用户名>`
  - Port: `22`（默认）
- OK 保存

此时将光标悬浮在 A 的 session 上，会显示 "SSH jump host" 的信息，表示配置成功。