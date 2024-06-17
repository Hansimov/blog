# 安装 Elastic Kibana


::: tip Install Kibana from archive on Linux
* https://www.elastic.co/guide/en/kibana/current/targz.html#install-linux64

Run Kibana from the command line
* https://www.elastic.co/guide/en/kibana/current/targz.html#targz-running
:::

## 安装


下载压缩包：

```sh
curl -O https://artifacts.elastic.co/downloads/kibana/kibana-8.14.1-linux-x86_64.tar.gz
```

校验 SHA512：（可选）

```sh
curl https://artifacts.elastic.co/downloads/kibana/kibana-8.14.1-linux-x86_64.tar.gz.sha512 | shasum -a 512 -c -
```

校验正确应当输出：`kibana-8.14.1-linux-x86_64.tar.gz: OK`

解压缩：

```sh
tar -xzf kibana-8.14.1-linux-x86_64.tar.gz -C ~
```

## 启动

确保 Elasticsearch 已经安装和启动，可参考 [安装 Elasticsearch](./elastic-search.md)。

```sh
cd ~/kibana-8.14.1/
./bin/kibana
```

首次启动 Kibana 时，该命令会在终端中生成一个唯一的链接，用于向 Elasticsearch 注册 Kibana 实例。

命令行输出形如：

```sh
Go to http://localhost:5601/?code=****** to get started.
```

- Kibana 默认运行端口为 `5601`。

用 Elasticsearch 生成注册令牌：

```sh
elasticsearch-create-enrollment-token -s kibana
```

令牌形如：

```sh
eyJ2ZX*********...*********In0=
```

- 复制 kibana 的链接到浏览器中打开，即可访问 Kibana。
- 粘贴 Elasticsearch 生成的注册令牌，然后单击按钮将 Kibana 实例与 Elasticsearch 连接。
- 以 Elasticsearch 的 `elastic` 用户名和密码登录 Kibana。

## 添加环境变量

将下列内容添加到 `.bashrc` 或 `.zshrc`：

```sh
export KIBANA_HOME=~/kibana-8.14.1
export PATH=$KIBANA_HOME/bin:$PATH
```

## 运行服务

```sh
kibana serve --host 0.0.0.0 --port 5601
```

## 命令行选项

```sh
kibana --help
```

```sh
Usage: bin/kibana [command=serve] [options]

Kibana is an open and free, browser based analytics and search dashboard for Elasticsearch.

Commands:
  serve  [options]  Run the kibana server
  help  <command>   Get the help for a specific command

"serve" Options:

  -e, --elasticsearch <uri1,uri2>  Elasticsearch instances
  -c, --config <path>              Path to the config file, use multiple --config args to include multiple config files (default: [])
  -p, --port <port>                The port to bind to
  -Q, --silent                     Set the root logger level to off
  --verbose                        Set the root logger level to all
  -H, --host <host>                The host to bind to
  -l, --log-file <path>            Deprecated, set logging file destination in your configuration
  --plugin-path <path>             A path to a plugin which should be included by the server, this can be specified multiple times to specify multiple paths
                                   (default: [])
  --optimize                       Deprecated, running the optimizer is no longer required
  -h, --help                       output usage information
```