# 安装 Docker

::: tip Install Docker Engine on Ubuntu | Docker Docs
* https://docs.docker.com/engine/install/ubuntu/#installation-methods
:::

## 安装

### 安装流程

添加 Docker 官方 GPG key：

```sh{4}
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

- 第 4 行`curl` 命令可能需要添加代理 `--proxy http://127.0.0.1:11111`
- 或者将 `download.docker.com` 替换为中科大的镜像源 `mirrors.ustc.edu.cn/docker-ce`

将 Docker 库添加到 APT 源：

```sh
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.ustc.edu.cn/docker-ce/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

- 注意：国内环境需要将 `download.docker.com` 替换为中科大的镜像源 `mirrors.ustc.edu.cn/docker-ce`

安装包：

```sh
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 一键安装

```
wget https://raw.staticdn.net/Hansimov/blog/main/docs/notes/scripts/docker_install.sh -O ~/docker_install.sh && chmod +x ~/docker_install.sh && ~/docker_install.sh
```

::: info 脚本: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/docker_install.sh
:::

<<< @/notes/scripts/docker_install.sh{sh}

## 添加镜像

### 修改 daemon.json 添加镜像源

::: tip See: dongyubin/DockerHub: 2025年11月更新，目前国内可用Docker镜像源汇总，DockerHub国内镜像加速列表
* https://github.com/dongyubin/DockerHub
:::

```sh
sudo nano /etc/docker/daemon.json
```

添加下面的内容：

- 可用时间：2025.11.25

```json
{
    "registry-mirrors": [
      "https://docker.1ms.run",
      "https://docker.1panel.live",
      "https://docker.m.daocloud.io"
  ]
}
```

重启 Docker 服务：

```sh
sudo systemctl daemon-reload && sudo systemctl restart docker
```

::: tip 总结国内还能用的 [Docker.io🐳 & Podman mirrors]镜像 6.13更新：国内源+1 & 国外源+1 - 配置调优 - LINUX DO
* https://linux.do/t/topic/108170
:::

### 命令行指定镜像源 dock pull 

样例：

```sh
docker pull docker.mybacc.com/nicolas/webdis
```

## 配置代理

在 `/etc/systemd/system/docker.service.d/proxy.conf` 中添加：

```sh
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:11111"
Environment="HTTPS_PROXY=http://127.0.0.1:11111"
Environment="NO_PROXY=localhost,127.0.0.1"
```

重启 Docker 服务：

```sh
sudo systemctl daemon-reload && sudo systemctl restart docker
```

::: tip Docker的三种网络代理配置 · 零壹軒·笔记
- https://note.qidong.name/2020/05/docker-proxy/
:::

## 重启 Docker 服务

```sh
sudo systemctl daemon-reload && sudo systemctl restart docker
```

## 为普通用户添加 Docker 权限

```sh
sudo usermod -aG docker $USER && newgrp docker
```

::: tip linux - docker.sock permission denied - Stack Overflow
* https://stackoverflow.com/questions/48568172/docker-sock-permission-denied
:::

## 检查是否配置成功

```sh
sudo docker run hello-world
```

如果该命令未能成功运行，大概率是网络问题，参见 [添加镜像](#添加镜像) 或 [配置代理](#配置代理)。

若运行成功，输出应形如：

<details> <summary> <code>Hello from Docker!</code> </summary>

```sh{7}
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
c1ec31eb5944: Pull complete
Digest: sha256:94323f3e5e09a8b9515d74337010375a456c909543e1ff1538f5116d38ab3989
Status: Downloaded newer image for hello-world:latest

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (amd64)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started/
```

</details>

## GPU 容器支持

Docker 本身只负责容器引擎。GPU 容器需要在 NVIDIA 驱动可用之后，另外安装 NVIDIA Container Toolkit，见：[安装 NVIDIA Container Toolkit](./nvidia-container.md)。

`docs/notes/scripts/pve-ubuntu/setup_ubuntu.sh` 的 `docker` 阶段只安装 Docker CE、配置 registry mirror 和 daemon 代理；`nvidia_container` 阶段才安装 NVIDIA Container Toolkit 并写入 `/etc/docker/daemon.json`。
