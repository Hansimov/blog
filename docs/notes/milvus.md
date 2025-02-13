# 安装 Milvus、SDK 和 CLI

## 通过 docker-compose 安装运行 Milvus

::: tip Run Milvus with Docker Compose (Linux)
https://milvus.io/docs/install_standalone-docker-compose.md
:::

### 下载 docker-compose.yml

```sh
wget https://github.com/milvus-io/milvus/releases/download/v2.5.4/milvus-standalone-docker-compose.yml -O docker-compose.yml
```

或者使用 `curl` 经过代理下载：

```sh
curl -L --proxy http://127.0.0.1:11111 https://github.com/milvus-io/milvus/releases/download/v2.5.4/milvus-standalone-docker-compose.yml -o docker-compose.yml
```

### 拉取镜像

可以查看都包含哪些镜像：

```sh
cat docker-compose.yml | grep image
```

拉取相关镜像：
- 若拉取较慢，可以换别的源，并将 `docker-compose.yml` 中的对应 `image` 替换为新的源
- 或者加上环境变量 `https_proxy=http://127.0.0.1:11111` 使用代理

```sh
docker pull quay.io/coreos/etcd:v3.5.0 # docker pull rancher/mirrored-coreos-etcd:v3.5.0
docker pull minio/minio:RELEASE.2020-12-03T00-03-10Z
docker pull milvusdb/milvus:v2.5.4
```


### 自定义配置

::: tip Configure Milvus with Docker Compose | Milvus Documentation
* https://milvus.io/docs/configure-docker.md?tab=component
:::

下载默认配置文件：

```sh
wget http://raw.staticdn.net/milvus-io/milvus/v2.5.4/configs/milvus.yaml
```

修改 `milvus.yaml` 中相关的项，例如：
- 提高 vector 类型的列数限制：`maxVectorFieldNum` 从 `4` 改为 `10`
- 关闭自动段合并（否则会周期性地高占用CPU）：`enableCompaction` 从 `true` 改为 `false`
  - 详见 [常见问题：周期性高CPU占用](#周期性高-cpu-占用)

```sh
proxy:
  maxVectorFieldNum: 10 # The maximum number of vector fields that can be specified in a collection. Value range: [1, 10].

dataCoord:
  # Switch value to control if to enable segment compaction.
  # Compaction merges small-size segments into a large segment, and clears the entities deleted beyond the rentention duration of Time Travel.
  enableCompaction: false
```

在 `docker-compose.yml` 中添加对应的 `volumes`：

```yaml{9}
services:
  ...
  standalone:
    container_name: milvus-standalone
    image: milvusdb/milvus:v2.5.4
    command: ["milvus", "run", "standalone"]
    ...
    volumes:
      - ${DOCKER_VOLUME_DIRECTORY:-.}/milvus.yaml:/milvus/configs/milvus.yaml
      - ${DOCKER_VOLUME_DIRECTORY:-.}/volumes/milvus:/var/lib/milvus
```

### 运行 Milvus

```sh
docker compose up
```

或者更完整一点：

```sh
docker compose build && docker compose down && docker compose up
```

查看运行状态：

```sh
docker compose ps
```

如果正常运行，输出形如：

```sh
NAME                IMAGE                                      COMMAND                  SERVICE      CREATED              STATUS                        PORTS
milvus-etcd         quay.io/coreos/etcd:v3.5.16                "etcd -advertise-cli…"   etcd         About a minute ago   Up About a minute (healthy)   2379-2380/tcp
milvus-minio        minio/minio:RELEASE.2023-03-20T20-16-18Z   "/usr/bin/docker-ent…"   minio        About a minute ago   Up About a minute (healthy)   0.0.0.0:9000-9001->9000-9001/tcp, :::9000-9001->9000-9001/tcp
milvus-standalone   milvusdb/milvus:v2.5.4                     "/tini -- milvus run…"   standalone   About a minute ago   Up About a minute (healthy)   0.0.0.0:9091->9091/tcp, :::9091->9091/tcp, 0.0.0.0:19530->19530/tcp, :::19530->19530/tcp
```

### 常见问题

#### minio 报错

```sh
milvus-minio       | ERROR Unable to use the drive /minio_data: Drive /minio_data: found backend type fs, expected xl or xl-single
```

原因：运行过不同版本的 docker-compose.yml，导致 minio 数据格式不兼容

解决：删除 `volumes` 目录，重新运行

#### 周期性高 CPU 占用

::: warning [Bug]: Milvus (2.5.4) periodically utilizing high cpu, even when there is no in-progress tasks of query and index. · Issue #39830 · milvus-io/milvus
* https://github.com/milvus-io/milvus/issues/39830
:::

原因：Milvus 默认开启了自动段合并（compaction）

解决：将 `milvus.yaml` 中的 `enableCompaction` 从 `true` 改为 `false`，重启 Milvus 镜像

## 安装 Pymilvus

::: tip Install Milvus Python SDK | Milvus Documentation
* https://milvus.io/docs/install-pymilvus.md
:::

```sh
pip install pymilvus==2.5.4
```

验证安装：

```sh
python -c "import pymilvus; print(pymilvus.__version__)"
```

## 安装 Milvus CLI

::: tip Install Milvus_CLI | Milvus Documentation
* https://milvus.io/docs/install_cli.md
:::

```sh
pip install milvus-cli
```

验证安装：

```sh
milvus --version
```

## 安装 GUI 管理工具 Attu

::: tip zilliztech/attu: The GUI for Milvus
* https://github.com/zilliztech/attu
:::

下载镜像：

```sh
docker pull zilliz/attu:v2.4
```

运行：

```sh
docker run -p 9009:3000 -e MILVUS_URL=127.0.0.1:19530 zilliz/attu:v2.4
```

浏览器访问 `http://<server_ip>:9009` 即可。

## pprof 查看性能日志

Dump 日志：

```sh
wget -O trace.out "http://localhost:9091/debug/pprof/trace?seconds=60"
```

查看：

```sh
go tool trace -http=0.0.0.0:40843 trace.out
```

访问 http://<server_ip>:40843 即可查看