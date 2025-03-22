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


解压缩到 HOME 目录，其文件名默认为 `elasticsearch-8.14.1`：

```sh
tar -xzf elasticsearch-8.14.1-linux-x86_64.tar.gz -C ~
```

## 启动

```sh
cd ~/elasticsearch-8.14.1
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

重新加载配置：

```sh
zsh
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

## 安装 Python client

```sh
pip install elasticsearch --upgrade
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
cd ~/elasticsearch-8.14.1/
./bin/elasticsearch
```

或者：（可执行程序已经添加到环境变量）

```sh
elasticsearch
```

### 查看已安装插件

```sh
elasticsearch-plugin list
```

## 升级 ElasticSearch

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