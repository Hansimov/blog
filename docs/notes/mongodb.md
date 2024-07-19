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