# 安装 Qdrant

::: tip Local Quickstart - Qdrant
* https://qdrant.tech/documentation/quickstart/

Installation - Qdrant
  * https://qdrant.tech/documentation/guides/installation/#production
:::


## docker 拉取镜像

```sh
docker pull qdrant/qdrant
```

## docker 运行

```sh
docker run -p 6333:6333 \
    -v $(pwd)/path/to/data:/qdrant/storage \
    -v $(pwd)/path/to/custom_config.yaml:/qdrant/config/custom_config.yaml \
    qdrant/qdrant \
    ./qdrant --config-path config/custom_config.yaml
```

## docker-compose 运行

本地创建 `docker-compose.yml`：

```yaml
services:
  qdrant:
    image: qdrant/qdrant:latest
    restart: always
    container_name: qdrant
    ports:
      - 6333:6333
      - 6334:6334
    expose:
      - 6333
      - 6334
      - 6335
    configs:
      - source: qdrant_config
        target: /qdrant/config/production.yaml
    volumes:
      - ./qdrant_data:/qdrant/storage

configs:
  qdrant_config:
    content: |
      log_level: INFO
```

运行：

```sh
docker compose build && docker compose down && docker compose up
```

## Web UI

默认在：
- http://localhost:6333/dashboard

## 安装 Python Client

::: tip Qdrant Python Client Documentation — Qdrant Client documentation
* https://python-client.qdrant.tech/
:::

```sh
pip install qdrant-client
```