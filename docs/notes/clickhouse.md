# 安装 Clickhouse

::: tip Install ClickHouse
* https://clickhouse.com/docs/install

clickhouse/clickhouse-server - Docker Image | Docker Hub
* https://hub.docker.com/r/clickhouse/clickhouse-server/

Network ports
* https://clickhouse.com/docs/guides/sre/network-ports
:::

## 安装 clickhouse-server

### 拉取镜像

```sh
docker pull clickhouse/clickhouse-server
```

### 配置 docker-compose.yml

```sh
cd ~/clickhouse && touch docker-clickhouse.yml
```

添加如下内容：

```yml
services:
  clickhouse:
    image: clickhouse/clickhouse-server
    container_name: clickhouse-server
    ports:
      - "8123:8123"
      - "9000:9000"
    network_mode: host
    volumes:
      - "~/clickhouse/data:/var/lib/clickhouse"
      - "~/clickhouse/log:/var/log/clickhouse-server"
      - "~/clickhouse/config.d:/etc/clickhouse-server/config.d"
      - "~/clickhouse/users.d:/etc/clickhouse-server/users.d"
    env_file: "~/clickhouse/.env"
```

创建 `.env` 文件：

```sh
touch ~/clickhouse/.env
```

添加如下内容：

```sh
CLICKHOUSE_USER=xxxx
CLICKHOUSE_PASSWORD=******
VITE_CLICKHOUSE_USER=xxxx
VITE_CLICKHOUSE_PASS=******
VITE_CLICKHOUSE_URL=http://<server-name>:8123
```

### 允许远程访问

::: warning Error: Connection failed (Invalid or missing ClickHouse credentials) · Issue #57 · caioricciuti/ch-ui
* https://github.com/caioricciuti/ch-ui/issues/57
:::

```sh
cd ~/clickhouse/config.d
sudo touch listen_host.xml
sudo nano listen_host.xml
```

添加如下内容：

```xml
<yandex>
  <listen_host>0.0.0.0</listen_host>
  <tcp_port>9000</tcp_port>
  <http_port>8123</http_port>
</yandex>
```

### 启动 clickhouse-server

```sh
docker compose -f docker-clickhouse.yml up --build
```

或者：

```sh
docker compose -f docker-clickhouse.yml down && docker compose -f docker-clickhouse.yml up --build
```

### 端口解释

- `8123`: HTTP 端口
- `9000`: `clickhouse-client` 和 `clickhouse-server` 的通信端口


### 测试服务

```sh
curl http://localhost:8123
```

输出形如：

```sh
Ok.
```

```sh
curl http://localhost:9000
```

输出形如：

```sh
Port 9000 is for clickhouse-client program
You must use port 8123 for HTTP.
```

### 关闭服务

```sh
docker compose down
```

### 删除 container

```sh
docker rm clickhouse-instance
```

## 安装 clickhouse-client

::: tip ClickHouse Client
* https://clickhouse.com/docs/interfaces/cli
:::

```sh
cd ~/downloads
curl https://clickhouse.com/ | sh
sudo ./clickhouse install
```

### 命令行连接服务

```sh
clickhouse-client --host localhost --port 9000 --user xxx --password xxx
```

## 安装 ch-ui
::: tip * caioricciuti/ch-ui: CH-UI is a modern and feature-rich user interface for ClickHouse databases.
  * https://github.com/caioricciuti/ch-ui
:::

### 拉取镜像

```sh
docker pull ghcr.io/caioricciuti/ch-ui:latest
```

### 配置 docker-compose.yml

```sh
cd ~/clickhouse && touch docker-chui.yml
```

添加如下内容：

```yml
services:
  ch-ui:
    image: ghcr.io/caioricciuti/ch-ui:latest
    container_name: ch-ui
    network_mode: host
    ports:
      - "5521:5521"
    env_file: "~/clickhouse/.env"
```

### 启动 ch-ui

```sh
docker compose -f docker-chui.yml up --build
```

或者：

```sh
docker compose -f docker-chui.yml down && docker compose -f docker-chui.yml up --build
```

访问 `http://<server-name>:5521` 即可查看 ch-ui 页面。

## 安装 clickhouse-connect
::: tip Python Integration with ClickHouse Connect | ClickHouse Docs
* https://clickhouse.com/docs/integrations/python
:::

```sh
pip install clickhouse-connect --index-url https://mirrors.ustc.edu.cn/pypi/simple
```