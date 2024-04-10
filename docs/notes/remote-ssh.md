# 在 VSCode 中使用 Remote SSH

## 配置 ssh 密钥

如果无法通过密码登录到远程服务器，可能是因为远程服务器没有启用 PasswordAuthentication。
所以需要使用公钥的方法登录。

在本机运行：

```sh
ssh-keygen
```

这会生成一个 ssh 的密钥对。然后将公钥复制到远程服务器。

在本机运行：
* 可以在 Git 控制台中使用 `ssh-copy-id`

```sh
ssh-copy-id <username>@<hostname>
```

完成上述步骤，即可用下面的命令登录到远程服务器：

* 不要忘记指定用户名 `<username>@`

```sh
ssh <username>@<hostname>
```

如果使用配置文件进行 SSH，需要在本机的配置文件中添加以下内容：
- Windows: `C:\Users\xxx\.ssh\config`

```sh
Host <host_ip>
    HostName <hostname>
    User <username>
```

## 根据机器名连接 SSH

将机器名映射到 IP 地址：

- 假设机器的 hostname 为 `olivaw`，IP 地址为 `192.168.1.105`

在 hosts 文件中添加如下内容：

- Ubuntu: `/etc/hosts`
- Windows: `C:\Windows\System32\drivers\etc\hosts`

```sh
192.168.1.105 olivaw
```

然后 ssh 连接：

```sh
ssh <user>@<hostname>
```

::: tip See: Cannot ssh into Ubuntu Server by hostname - Ask Ubuntu
* https://askubuntu.com/questions/144280/cannot-ssh-into-ubuntu-server-by-hostname
:::