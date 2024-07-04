# 安装 Docker

::: tip Install Docker Engine on Ubuntu | Docker Docs
* https://docs.docker.com/engine/install/ubuntu/#installation-methods
:::

## 安装

添加 Docker 官方 GPG key：

```sh
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

将 Docker 库添加到 APT 源：

```sh
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

安装包：

```sh
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

检查是否安装成功：

```sh
sudo docker run hello-world
```

如果该命令未能成功运行，可能是代理问题，参见[配置代理](#配置代理)。

## 配置代理

::: tip Docker的三种网络代理配置 · 零壹軒·笔记
- https://note.qidong.name/2020/05/docker-proxy/
:::

在 `/etc/systemd/system/docker.service.d/proxy.conf` 中添加：

```sh
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:11111"
Environment="HTTPS_PROXY=http://127.0.0.1:11111"
Environment="NO_PROXY=localhost,127.0.0.1"
```

然后重启 Docker 服务。

## 重启 Docker 服务

```sh
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## 一键安装

```
wget https://raw.githubusercontent.com/Hansimov/blog/main/docs/notes/scripts/docker_install.sh -O ~/docker_install.sh && chmod +x ~/docker_install.sh && ~/docker_install.sh
```

::: info 脚本: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/docker_install.sh
:::

<<< @/notes/scripts/docker_install.sh{sh}