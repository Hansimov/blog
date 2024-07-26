# 安装 MongoDB

::: tip 在 Ubuntu 上安装 MongoDB Community Edition - MongoDB 手册 v7.0
* https://www.mongodb.com/zh-cn/docs/manual/tutorial/install-mongodb-on-ubuntu/
:::

安装系统为 Ubuntu 22.04。

## 安装

安装依赖包：

```sh
sudo apt-get install gnupg curl
```

导入 MongoDB GPG 密钥：

```sh
curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
```

* 国内访问 `www.mongodb.org/static` 有点慢，可能需要走代理

创建 MongoDB 列表文件：

```sh
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
```

重新加载本地包列表：

```sh
sudo apt-get update
```

安装最新版本的 MongoDB：

```sh
sudo apt-get install -y mongodb-org
```

## 路径

### 目录
如果通过软件包管理器安装，则在安装过程中会创建数据目录 `/var/lib/mongodb` 和日志目录 `/var/log/mongodb`。

默认情况下，MongoDB 使用 `mongodb` 用户账户运行。

如果更改运行 MongoDB 进程的用户，则必须修改数据和日志目录以赋予该用户访问这些目录的权限。

### 配置文件
MongoDB 官方软件包有一份配置文件 (`/etc/mongod.conf`)。这些设置（如数据目录和日志目录规范）将在启动时生效。

换言之，如果在 MongoDB 实例运行时更改该配置文件，则必须<m>重新启动实例</m>才能使更改生效。

## 运行

以下运行步骤假定使用官方 mongodb-org 包且使用默认设置，而非 Ubuntu 提供的非官方 mongodb 包。

### 初始化系统

查看初始化系统：

```sh
ps --no-headers -o comm 1
```

默认输出：

```sh
systemd
```

### 启动

```sh
sudo systemctl start mongod
```

### 开机启动服务

```sh
sudo systemctl enable mongod
```

### 查看状态

```sh
sudo systemctl status mongod
```

### 停止

```sh
sudo systemctl stop mongod
```

### 重启

```sh
sudo systemctl restart mongod
```

### 命令行进入

```sh
mongosh
```

默认端口为 `27017`。


## 允许远程访问

::: tip IP 绑定 — MongoDB 手册 v7.0
* https://www.mongodb.com/zh-cn/docs/manual/core/security-mongodb-configuration/

* 配置文件选项 — MongoDB 手册 v7.0
  * https://www.mongodb.com/zh-cn/docs/manual/reference/configuration-options/#mongodb-setting-net.bindIp
:::

修改配置文件 `nano /etc/mongod.conf`，将 `bindIp` 改为 `0.0.0.0`，以允许所有 IP 远程访问：

```sh
# network interfaces
net:
  port: 27017
  # bindIp: 127.0.0.1
  bindIp: 0.0.0.0
```

重启服务：

```sh
sudo systemctl restart mongod
```

## 设置内存占用上限

::: tip Is there any option to limit mongodb memory usage? - Stack Overflow
* https://stackoverflow.com/questions/6861184/is-there-any-option-to-limit-mongodb-memory-usage

storage.wiredTiger.engineConfig.cacheSizeGB
* https://www.mongodb.com/zh-cn/docs/manual/reference/configuration-options/#mongodb-setting-storage.wiredTiger.engineConfig.cacheSizeGB
:::

修改配置文件 `/etc/mongod.conf`，例如，将缓存上限设为 32GB：

```sh{4}
storage:
  wiredTiger:
    engineConfig:
      cacheSizeGB: 32
```

重启服务：

```sh
sudo systemctl restart mongod
```

## 安装 GUI 工具

::: tip 13个Mongodb GUI可视化管理工具，总有一款适合你-阿里云开发者社区
* https://developer.aliyun.com/article/721720
:::

### MongoDB Compass

* https://www.mongodb.com/try/download/compass

- 界面比较简陋，不过可以在设置里改成暗色模式

注意要下载完整版（区别于只读版和隔离版） ：
- 1.43.4 (Stable)
- https://downloads.mongodb.com/compass/mongodb-compass-1.43.4-win32-x64.exe


### Studio 3T

* https://studio3t.com/download/

- 启动略慢
- 颜值比 Compass 高很多
- 需要注册账号，填写手机号，才能试用 30 天（免费版无法 SQL 查询）

### 连接到远程 MongoDB

```sh
mongodb://<hostname>:27017
```

## 部署副本集

::: tip 将独立运行的 mongod 转换为副本集 - MongoDB 手册 v7.0
  * https://www.mongodb.com/zh-cn/docs/manual/tutorial/convert-standalone-to-replica-set/#convert-a-standalone-mongod-to-a-replica-set
:::

### 使用配置文件部署副本集

#### 关闭实例服务

```sh
sudo systemctl stop mongod
```

#### 配置副本集

```sh
nano /etc/mongod.conf
```

添加如下内容：

```sh
replication:
  replSetName: "rs0"
  # oplogSizeMB: <int>
  # enableMajorityReadConcern: <boolean>
```

- `replSetName`: 副本集名称
- `oplogSizeMB`: oplog 大小，默认为磁盘空间的 5%
- `enableMajorityReadConcern`: 从 v5.0 开始不可更改，始终为 `true`，

::: tip 配置文件选项: `replication.replSetName`
* https://www.mongodb.com/zh-cn/docs/manual/reference/configuration-options/#mongodb-setting-replication.replSetName
* https://www.mongodb.com/zh-cn/docs/manual/reference/configuration-options/#replication-options
:::

#### 启动服务
```sh
sudo systemctl start mongod
```

#### 初始化副本集

进入命令行：

```sh
mongosh
```

初始化副本集：

```sh
rs.initiate()
```

输出形如：

```sh
{
  info2: 'no configuration specified. Using a default configuration for the set',
  me: '<hostname>:27017',
  ok: 1
}
```

查看副本集配置：

```sh
rs.conf()
```

输出形如：

```sh
{
  _id: 'rs0',
  version: 1,
  term: 1,
  members: [
    {
      _id: 0,
      host: '<hostname>:27017',
      arbiterOnly: false,
      buildIndexes: true,
      hidden: false,
      priority: 1,
      tags: {},
      secondaryDelaySecs: Long('0'),
      votes: 1
    }
  ],
  ...
}
```

查看副本集状态：

```sh
rs.status()
```

### 使用命令行部署副本集

#### 关闭实例

```sh
mongosh
```

```sh
use admin
db.adminCommand( { shutdown: 1, comment: "Convert to cluster" } )
```

#### 启动实例

样例：

```sh
mongod --replSet rs0 --port 27017 --dbpath /path/to/mongodb/dbpath --authenticationDatabase "admin" --username "adminUser" --password
```

参数说明：

- `--replSet`: 副本集名称 
- `--port`: 进程端口
- `--dbpath`: 数据库路径
- `--authenticationDatabase`, `--username`, `--password`: 身份验证

#### 初始化副本集

[同上](#初始化副本集)。