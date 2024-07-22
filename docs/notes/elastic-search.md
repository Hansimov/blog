# 安装 Elastic Search

::: tip Quick start guide - Elasticsearch 8.14
* https://www.elastic.co/guide/en/elasticsearch/reference/current/getting-started.html
:::

## 下载和安装

::: tip Installing Elasticsearch
* https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html

Download and install archive for Linux
* https://www.elastic.co/guide/en/elasticsearch/reference/current/targz.html#install-linux

Run Elasticsearch from the command line
* https://www.elastic.co/guide/en/elasticsearch/reference/current/targz.html#targz-running
:::


下载压缩包：

```sh
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.14.1-linux-x86_64.tar.gz
```

校验 SHA512：（可选）


```sh
wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-8.14.1-linux-x86_64.tar.gz.sha512
shasum -a 512 -c elasticsearch-8.14.1-linux-x86_64.tar.gz.sha512
```

校验正确应当输出：`elasticsearch-8.14.1-linux-x86_64.tar.gz: OK`


解压缩：

```sh
tar -xzf elasticsearch-8.14.1-linux-x86_64.tar.gz -C ~
```

## 启动

```sh
cd ~/elasticsearch-8.14.1/
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

## 添加环境变量

将下列内容添加到 `.bashrc` 或 `.zshrc`：

```sh
export ES_HOME=~/elasticsearch-8.14.1
export ELASTIC_PASSWORD="<your_password>"
export PATH=$ES_HOME/bin:$PATH
```

## 检查 Elasticsearch 是否运行

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
    "number" : "8.14.1",
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

## 重置密码

```sh
elasticsearch-reset-password -u elastic
```

## 在集群中注册新节点

首先在运行 Elasticsearch 的终端中执行：

```sh
elasticsearch-create-enrollment-token -s node
```

然后在新节点的目录下执行：

```sh
elasticsearch --enrollment-token <enrollment-token>
```

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

## 安装 Python client

```sh
pip install elasticsearch
```

::: tip Python Client Examples
* https://www.elastic.co/guide/en/elasticsearch/client/python-api/current/examples.html

Python Client Helpers
* https://www.elastic.co/guide/en/elasticsearch/client/python-api/current/client-helpers.html
:::

## 安装插件

### 安装 Smart Chinese analysis 插件

```sh
elasticsearch-plugin install analysis-smartcn
```

::: tip Smart Chinese analysis plugin | Elasticsearch Plugins and Integrations [8.14] | Elastic
* https://www.elastic.co/guide/en/elasticsearch/plugins/current/analysis-smartcn.html
:::

### 安装 IK 分词插件

```sh
elasticsearch-plugin install https://get.infini.cloud/elasticsearch/analysis-ik/8.14.1
```

注意：`analysis-ik` 插件需要与 Elasticsearch 版本匹配。

::: tip infinilabs/analysis-ik: 🚌 The IK Analysis plugin integrates Lucene IK analyzer into Elasticsearch and OpenSearch, support customized dictionary.
* https://github.com/infinilabs/analysis-ik

Elasticsearch 中文分词器-阿里云开发者社区
* https://developer.aliyun.com/article/848626
:::


### 安装 pinyin 插件

```sh
elasticsearch-plugin install https://get.infini.cloud/elasticsearch/analysis-pinyin/8.14.1
```

注意：`analysis-pinyin` 插件需要与 Elasticsearch 版本匹配。

::: tip infinilabs/analysis-pinyin: 🛵 This Pinyin Analysis plugin is used to do conversion between Chinese characters and Pinyin.
* https://github.com/infinilabs/analysis-pinyin
:::

### 安装 stconvert 插件

```sh
elasticsearch-plugin install https://get.infini.cloud/elasticsearch/analysis-stconvert/8.14.1
```

注意：`analysis-stconvert` 插件需要与 Elasticsearch 版本匹配。

::: tip infinilabs/analysis-stconvert: 中文简繁體互相转换.
* https://github.com/infinilabs/analysis-stconvert
:::

### 重启 Elasticsearch 以使插件生效

```sh
elasticsearch
```

### 查看已安装插件

```sh
elasticsearch-plugin list
```

## 创建 connector

::: tip Running from a Docker container | Enterprise Search documentation [8.14] | Elastic
* https://www.elastic.co/guide/en/enterprise-search/8.14/connectors-run-from-docker.html

connectors/config.yml.example
* https://github.com/elastic/connectors/blob/main/config.yml.example

Using connectors | Enterprise Search documentation [8.14] | Elastic
* https://www.elastic.co/guide/en/enterprise-search/current/connectors-usage.html

Elastic MongoDB connector reference | Enterprise Search documentation [8.14] | Elastic
* https://www.elastic.co/guide/en/enterprise-search/current/connectors-mongodb.html
:::

这里以 MongoDB Connector 为例。ElasticSearch 版本为 `8.14.1`。

### 创建 Connector 和 API key

- 首先在标题栏搜索 `connectors`，进入页面 `Search > Content > Connectors`
- 点击 `New connector`，选择 `MongoDB`，填入 `Connector name`，点击 `Create connector`
- 在 `Attach an index` 中选择已有的索引或新建一个，点击 `Save configuration`
- 点击 `Generate API key`，生成对应的 api key 和 `config.yml`

### 克隆 connectors 仓库

在本地 `~/repos` 下运行：

```sh
git clone https://github.com/elastic/connectors.git
```

复制 `http_ca.crt` 文件到 `connectors` 目录下：

```sh
cp ~/elasticsearch-8.14.1/config/certs/http_ca.crt ~/repos/connectors
```

下面操作的路径目录均为 `~/repos/connectors`。

创建 `config.yml`，内容如下：

```sh
connectors:
  - connector_id: "zADx****************"
    service_type: "mongodb"
    api_key: "RGRB******************************************************=="
elasticsearch:
  host: "https://localhost:9200"
  api_key: "RGRB******************************************************=="
  ca_certs: "/config/http_ca.crt"
```

- 注意 `host` 是 `https` 而不是 `http`
- `connector_id` 是自动生成的
- `RGRB****...` 为 api key
- `ca_certs` 为证书文件路径，<m>如果不加会报错</m>

### 运行 docker 容器

创建 `run_docker.sh`，内容如下：

```sh
docker run -v ".:/config" --rm --tty -i --network host docker.elastic.co/enterprise-search/elastic-connectors:8.14.1.0 /app/bin/elastic-ingest -c /config/config.yml
```

- 需要注意 `elastic-connectors` 的版本要和 `ElasticSearch` 的版本一致

运行：
  
```sh
chmod +x run_docker.sh
./run_docker.sh
```

### 连接 MongoDB

配置 MongoDB 的连接信息：

- `Server hostname`: `mongodb://localhost:27017/`
- `Database`: ...
- `Collection`: ...
- `Direct connection`: `false`
- `SSL/TLS Connection`: `false`

点击 `Sync`，选择 `Full Content`，即可开始同步。


### 停止 docker 容器

查看正在运行的 docker 容器：

```sh
docker ps
```

然后停止容器：

```sh
docker stop $(docker ps -q --filter ancestor="docker.elastic.co/enterprise-search/elastic-connectors:8.14.1.0" )
```

### Common issue

点击 Sync 之后没有反应。（当前未能解决，故暂时不使用 Connector）