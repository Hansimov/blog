# 安装 Redis

::: tip redis - Official Image | Docker Hub
* https://hub.docker.com/_/redis

Redis configuration | Docs
* https://redis.io/docs/latest/operate/oss_and_stack/management/config/
* https://redis.io/docs/latest/operate/oss_and_stack/management/config-file/

redis.conf
* https://github.com/redis/redis/blob/8.0/redis.conf
* https://github.com/redis/redis/raw/refs/heads/8.0/redis.conf

Redis configuration file | Docs
* https://redis.io/docs/latest/operate/oss_and_stack/management/persistence/

nicolas/webdis - Docker Image | Docker Hub
* https://github.com/nicolasff/webdis/tree/master
* https://hub.docker.com/r/nicolas/webdis
* https://github.com/nicolasff/webdis/blob/master/docs/webdis-redis-docker-compose.md
* https://github.com/nicolasff/webdis/blob/master/webdis.json
:::

## 在 Docker 中运行 Redis

0. 创建目录：

    ```sh
    mkdir redis && cd redis
    ```

1. 添加 [`docker-compose.yml`](#docker-compose-yml)
   
   ```sh
   touch docker-compose.yml
   ```

2. 添加 [`redis.conf`](#redis-conf)：

    ```sh
    wget https://raw.staticdn.net/redis/redis/8.0/redis.conf -O redis.conf
    ```

    `redis.conf` 部分配置修改如下：

    ```sh
    maxmemory 200gb
    requirepass defaultpass
    # bind 127.0.0.1 -::1
    bind 0.0.0.0
    ```

3. 添加 [`webdis.json`](#webdis-json)：

    ```sh
    docker pull docker.mybacc.com/nicolas/webdis
    wget https://githubfast.com/nicolasff/webdis/raw/refs/heads/master/webdis.json -O webdis.json
    ```

    `webdis.json` 部分配置修改如下：

    ```json
    {
    "redis_host": "redis",
    "redis_port": 6379,
    "redis_auth": [
        "default",
        "defaultpass"
    ]
    }
    ```

4. 运行 `docker compose`：

   ```sh
   docker compose build && docker compose down && docker compose up
   ```

5. 通过 webdis 测试 redis 服务状态：

   ```sh
   curl http://127.0.0.1:7379/PING
   ```

   应当返回：

   ```json
   {"PING":[true,"PONG"]}
   ```

6. 【可选】下载安装 GUI 管理软件：[Redis Insight](https://redis.io/downloads/#:~:text=Redis-,Insight,-Download%20a%20powerful)

## 样例配置

### docker-compose.yml

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/redis-docker/docker-compose.yml
:::

<details> <summary><code>docker-compose.yml</code></summary>

<<< @/notes/configs/redis-docker/docker-compose.yml

</details>

### redis.conf

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/redis-docker/redis.conf
:::

<details> <summary><code>redis.conf</code></summary>

<<< @/notes/configs/redis-docker/redis.conf

</details>


### webdis.json

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/redis-docker/webdis.json
:::

<details> <summary><code>webdis.json</code></summary>

<<< @/notes/configs/redis-docker/webdis.json

</details>


### 复制本地配置到笔记

```sh
cp ~/redis/docker-compose.yml ~/repos/blog/docs/notes/configs/redis-docker/docker-compose.yml
cp ~/redis/redis.conf ~/repos/blog/docs/notes/configs/redis-docker/redis.conf
cp ~/redis/webdis.json ~/repos/blog/docs/notes/configs/redis-docker/webdis.json
```