# 安装 Elastic Search

::: tip Quick start guide - Elasticsearch 8.14
* https://www.elastic.co/guide/en/elasticsearch/reference/current/getting-started.html
:::

## 在本地运行 ElasticSearch
### 下载和安装

::: tip Installing Elasticsearch
* https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html

Download and install archive for Linux
* https://www.elastic.co/guide/en/elasticsearch/reference/current/targz.html#install-linux

Run Elasticsearch from the command line
* https://www.elastic.co/guide/en/elasticsearch/reference/current/targz.html#targz-running
:::

下载压缩包：

```sh
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.17.3-linux-x86_64.tar.gz
```

校验 SHA512：（可选）

```sh
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.17.3-linux-x86_64.tar.gz.sha512
shasum -a 512 -c elasticsearch-8.17.3-linux-x86_64.tar.gz.sha512
```

校验正确应当输出：`elasticsearch-8.17.3-linux-x86_64.tar.gz: OK`

解压缩到 HOME 目录，其文件名默认为 `elasticsearch-8.17.3`：

```sh
tar -xzf elasticsearch-8.17.3-linux-x86_64.tar.gz -C ~
```

### 启动 Elasticsearch

```sh
cd ~/elasticsearch-8.17.3
./bin/elasticsearch
```

首次启动 Elasticsearch 时，默认情况下会启用并配置安全功能。以下安全配置会自动发生：

- 启用身份验证和授权，并为内置超级用户 `elastic` 生成密码。
  - elastic 用户的密码和 Kibana 的注册令牌会在终端输出。
- 为传输层和 HTTP 层生成 TLS 的证书和密钥，并使用这些密钥和证书启用和配置 TLS。
- 为 Kibana 生成注册令牌，有效期为 30 分钟。

命令行输出形如：

```sh
✅ Elasticsearch security features have been automatically configured!
✅ Authentication is enabled and cluster connections are encrypted.

ℹ️  Password for the elastic user (reset with `bin/elasticsearch-reset-password -u elastic`):
  ********************

ℹ️  HTTP CA certificate SHA-256 fingerprint:
  ****************************************************************

ℹ️  Configure Kibana to use this cluster:
• Run Kibana and click the configuration link in the terminal when Kibana starts.
• Copy the following enrollment token and paste it into Kibana in your browser (valid for the next 30 minutes):
  ********************************************************************************

ℹ️  Configure other nodes to join this cluster:
• On this node:
  ⁃ Create an enrollment token with `bin/elasticsearch-create-enrollment-token -s node`.
  ⁃ Uncomment the transport.host setting at the end of config/elasticsearch.yml.
  ⁃ Restart Elasticsearch.
• On other nodes:
  ⁃ Start Elasticsearch with `bin/elasticsearch --enrollment-token <token>`, using the enrollment token that you generated.
```

ElasticSearch 默认运行端口为 `9200`。

### 添加环境变量

将下列内容添加到 `.bashrc` 或 `.zshrc`：

```sh
export ES_HOME=~/elasticsearch-8.17.3
export ELASTIC_PASSWORD="<your_password>"
export PATH=$ES_HOME/bin:$PATH
```

重新加载配置：

```sh
zsh
```

### 检查 Elasticsearch 是否运行

```sh
curl --cacert $ES_HOME/config/certs/http_ca.crt -u elastic:$ELASTIC_PASSWORD https://localhost:9200
```

输出形如：

```json
{
  "name" : "<your_hostname>",
  "cluster_name" : "elasticsearch",
  "cluster_uuid" : "**********************",
  "version" : {
    "number" : "8.17.3",
    "build_flavor" : "default",
    "build_type" : "tar",
    "build_hash" : "****************************************",
    "build_date" : "2024-06-10T23:35:17.114581191Z",
    "build_snapshot" : false,
    "lucene_version" : "9.10.0",
    "minimum_wire_compatibility_version" : "7.17.0",
    "minimum_index_compatibility_version" : "7.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

### 重置密码

```sh
elasticsearch-reset-password -u elastic
```

### 在集群中注册新节点

首先在运行 Elasticsearch 的终端中执行：

```sh
elasticsearch-create-enrollment-token -s node
```

然后在新节点的目录下执行：

```sh
elasticsearch --enrollment-token <enrollment-token>
```

这里的 `<enrollment-token>` 是上一步生成的注册令牌。
Elasticsearch 会自动在 `config/certs` 目录下生成证书和密钥。

命令行选项：

```sh
elasticsearch-create-enrollment-token --help
```

```sh
Creates enrollment tokens for elasticsearch nodes and kibana instances

Option (* = required)  Description
---------------------  -----------
-E <KeyValuePair>      Configure a setting
-f, --force            Use this option to force execution of the command
                         against a cluster that is currently unhealthy.
-h, --help             Show help
* -s, --scope          The scope of this enrollment token, can be either "node"
                         or "kibana"
--url                  the URL where the elasticsearch node listens for
                         connections.
-v, --verbose          Show verbose output
```

### 复制证书到其他目录

```sh
cp $ES_HOME/config/certs/http_ca.crt ~/repos/bili-scraper/configs/elastic_ca.crt
```

### 安装 Python client

```sh
pip install elasticsearch --upgrade
```

::: tip Python Client Examples
* https://www.elastic.co/guide/en/elasticsearch/client/python-api/current/examples.html

Python Client Helpers
* https://www.elastic.co/guide/en/elasticsearch/client/python-api/current/client-helpers.html
:::

### 安装插件

#### 安装 Smart Chinese analysis 插件

```sh
elasticsearch-plugin install analysis-smartcn
```

::: tip Smart Chinese analysis plugin | Elasticsearch Plugins and Integrations [8.14] | Elastic
* https://www.elastic.co/guide/en/elasticsearch/plugins/current/analysis-smartcn.html
:::

#### 安装 IK 分词插件

```sh
elasticsearch-plugin install https://get.infini.cloud/elasticsearch/analysis-ik/8.17.3
```

注意：`analysis-ik` 插件需要与 Elasticsearch 版本匹配。

默认的 `stopword.dic` 文件中包含了一些停用词（stop word），分词的时候会被过滤。如果不想过滤这些词，可以将该 dic 文件清空：

```sh
cd $ES_HOME/config/analysis-ik
cp stopword.dic stopword.dic.bak && rm stopword.dic && touch stopword.dic
```

重启 Elasticsearch 以使清空配置的操作生效。

::: tip infinilabs/analysis-ik: 🚌 The IK Analysis plugin integrates Lucene IK analyzer into Elasticsearch and OpenSearch, support customized dictionary.
* https://github.com/infinilabs/analysis-ik

Elasticsearch 中文分词器-阿里云开发者社区
* https://developer.aliyun.com/article/848626
:::

#### 安装 pinyin 插件

```sh
elasticsearch-plugin install https://get.infini.cloud/elasticsearch/analysis-pinyin/8.17.3
```

注意：`analysis-pinyin` 插件需要与 Elasticsearch 版本匹配。

::: tip infinilabs/analysis-pinyin: 🛵 This Pinyin Analysis plugin is used to do conversion between Chinese characters and Pinyin.
* https://github.com/infinilabs/analysis-pinyin
:::

#### 安装 stconvert 插件

```sh
elasticsearch-plugin install https://get.infini.cloud/elasticsearch/analysis-stconvert/8.17.3
```

注意：`analysis-stconvert` 插件需要与 Elasticsearch 版本匹配。

::: tip infinilabs/analysis-stconvert: 中文简繁體互相转换.
* https://github.com/infinilabs/analysis-stconvert
:::

#### 重启 Elasticsearch 以使插件生效

```sh
cd ~/elasticsearch-8.17.3/
./bin/elasticsearch
```

或者：（可执行程序已经添加到环境变量）

```sh
elasticsearch
```

#### 查看已安装插件

```sh
elasticsearch-plugin list
```

输出形如：

```sh
analysis-ik
analysis-pinyin
analysis-smartcn
analysis-stconvert
```

### 升级 ElasticSearch

::: tip Elastic Installation and Upgrade Guide [8.17] | Elastic
* https://www.elastic.co/guide/en/elastic-stack/8.17/upgrading-elasticsearch.html
:::

1. 备份或清空数据
2. 关停所有数据库读写任务
3. 关停所有 ElasticSearch 和 Kibana 的服务
4. 下载新版本：（例如 `8.14.1` -> `8.17.3`）
  - 由于上面的过程都是在独立的目录下进行，所以可以直接下载新版本并解压缩
  - 只需要把所有步骤中的 `8.14.1` 替换为 `8.17.3` 即可
5. 升级 Kibana，详见：[升级 Kibana](./elastic-kibana#升级-kibana)


## 在 Docker 中运行 ElasticSearch

::: tip Start a multi-node cluster with Docker Compose | Elastic Docs
* https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-compose

elasticsearch/docs/reference/setup/install/docker/docker-compose.yml
* https://github.com/elastic/elasticsearch/blob/main/docs/reference/setup/install/docker/docker-compose.yml
* https://github.com/elastic/elasticsearch/blob/main/docs/reference/setup/install/docker/.env
:::

### 下载配置

下载 `.env` 和 `docker-compose.yml` 文件到当前目录：

```sh
ES_DOCKER_ROOT="$HOME/elasticsearch-docker-9.1.3"
mkdir -p $ES_DOCKER_ROOT && cd $ES_DOCKER_ROOT
```

```sh
wget https://githubfast.com/elastic/elasticsearch/raw/refs/heads/main/docs/reference/setup/install/docker/.env
wget https://githubfast.com/elastic/elasticsearch/raw/refs/heads/main/docs/reference/setup/install/docker/docker-compose.yml
```

### 修改配置

修改 `.env` 和 `docker-compose.yml`，参考[样例配置](#样例配置)。

- 挂载 `data` 和 `certs` 目录到 host
- 设置 PASSWORD 和 PORT 等环境变量
- 注释掉 `docker-compose.yml` 中的 `chown` 命令

### 启动 Docker

设置 `vm.max_map_count`， 以确保 Elasticsearch 有足够的内存映射：

```sh
sudo sysctl -w vm.max_map_count=262144
# cat /proc/sys/vm/max_map_count
```

::: tip docker 启动时报错：
* `ERROR: Elasticsearch died while starting up, with exit code 78`

Increase virtual memory | Elastic Docs
  * https://www.elastic.co/docs/deploy-manage/deploy/self-managed/vm-max-map-count

Elasticsearch Container Stopped with `Exit 78` state in Ubuntu 18.04 · Issue #1699 · laradock/laradock
  * https://github.com/laradock/laradock/issues/1699
:::

运行下列命令，启动：

```sh
docker compose build && docker compose down && docker compose up
```

::: tip Using the Docker images in production | Elastic Docs
* https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod
:::


<details> <summary>旧脚本修复权限问题</summary>

首次启动时，默认以 root 身份在 host 中创建 mount 的目录，会报权限错误。ElasticSearch 和 Kibana 都可能出现。

```sh
FATAL Error: Unable to write to UUID file at /usr/share/kibana/data/uuid. 
Ensure Kibana has sufficient permissions to read / write to this file. Error was: EACCES
```

所以需要设置目录权限，以使内部的 elasticsearch 进程可以访问这些目录：

```sh
# mkdir -p plugins
sudo chown -R 1000:1000 data certs plugins
```

* 如果不成功，试试在容器仍在运行时执行上面这行命令

同时注释掉 `docker-compose.yml` 中的下面这几行：（注意，首次启动时不要注释）

```sh
echo "Setting file permissions"
chown -R root:root config/certs;  # after first run, comment this line.
                                  # after first run, execute following line:
                                  # `sudo chown -R 1000:1000 data certs plugins`
```

::: warning 注意：如果 host 中的环境变量已经设置了 `ELASTIC_PASSWORD`，那么在容器中也会自动设置该变量。
此时 `.env` 中的设置会被忽略。
:::

重新启动：

```sh
docker compose build && docker compose down && docker compose up
```

</details>

<details open> <summary>新脚本已修复权限问题</summary>

::: tip 新的 `docker-compose.yml` 脚本已经解决了权限问题，无需手动修改权限。`setup` 容器会自动：
1. 创建必要的目录（`certs`, `data`, `plugins`）
2. 生成 SSL 证书
3. 将所有文件的所有权设置为 `1000:1000`（elasticsearch 用户）
4. 设置适当的文件权限
:::

</details>

容器日志输出下面的内容就表示成功：

```sh
setup-1   | Setting kibana_system password
setup-1   | All done!
setup-1 exited with code 0
```

检测 Elasticsearch 是否运行：

```sh
curl --cacert ./certs/ca/ca.crt -u elastic:$ELASTIC_PASSWORD https://localhost:19200
```

输出形如：

```json
{
  "name" : "es01",
  "cluster_name" : "es-docker-cluster",
  "cluster_uuid" : "df-****************SvQ",
  "version" : {
    "number" : "9.1.3",
    "build_flavor" : "default",
    "build_type" : "docker",
    "build_hash" : "0c781091a2f57de895a73a1391ff8426c0153c8d",
    "build_date" : "2025-08-24T22:05:04.526302670Z",
    "build_snapshot" : false,
    "lucene_version" : "10.2.2",
    "minimum_wire_compatibility_version" : "8.19.0",
    "minimum_index_compatibility_version" : "8.0.0"
  },
  "tagline" : "You Know, for Search"
}
```

### 复制证书到其他目录

```sh
ES_DOCKER_ROOT="$HOME/elasticsearch-docker-9.1.3"
cp $ES_DOCKER_ROOT/certs/ca/ca.crt ~/repos/bili-search/configs/elastic_ca_dev.crt
cp $ES_DOCKER_ROOT/certs/ca/ca.crt ~/repos/bili-scraper/configs/elastic_ca_dev.crt
```

### 样例配置

#### .env

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/elastic-docker/.env
:::

<details> <summary><code>.env</code></summary>

<<< @/notes/configs/elastic-docker/.env{2,5,8,18,22,26}

</details>

#### docker-compose.yml

<details> <summary><code>docker-compose.yml</code></summary>

<<< @/notes/configs/elastic-docker/docker-compose.yml

</details>

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/elastic-docker/docker-compose.yml
:::

#### 复制本地配置到笔记

```sh
cp ~/elasticsearch-docker/.env ~/repos/blog/docs/notes/configs/elastic-docker/.env
cp ~/elasticsearch-docker/docker-compose.yml ~/repos/blog/docs/notes/configs/elastic-docker/docker-compose.yml
```
