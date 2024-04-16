# 安装 Postgresql

## 安装

### Ubuntu

将最新版本的 PostgreSQL 添加到软件源中：

```sh
# Create the file repository configuration:
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# Import the repository signing key:
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
# Update the package lists:
sudo apt-get update
```

安装最新版本的 PostgreSQL（截至 2024-04-16，版本是 16）：

```sh
# Install the latest version of PostgreSQL.
# If you want a specific version, use 'postgresql-12' or similar instead of 'postgresql':
sudo apt-get -y install postgresql
```

::: tip See: Linux downloads (Ubuntu)
- https://www.postgresql.org/download/linux/ubuntu

Install and configure PostgreSQL
- https://ubuntu.com/server/docs/databases-postgresql

Apt - PostgreSQL wiki
  * https://wiki.postgresql.org/wiki/Apt
:::

为了让 `pg_ctl` 等命令可用，在 `.zshrc` 添加以下内容：

```sh
export PATH=/usr/lib/postgresql/16/bin:$PATH
```

::: warning postgresql - pg_ctl: command not found, what package has this command? - Ask Ubuntu
* https://askubuntu.com/questions/385416/pg-ctl-command-not-found-what-package-has-this-command
:::

### Windows

点击、下载并安装：

- https://sbp.enterprisedb.com/getfile.jsp?fileid=1258893

假设 postgresql 安装路径为 `D:\postgresql\16`，那么需要将 `D:\postgresql\16\bin` 加到系统环境变量 `Path` 中。

::: tip See: PostgreSQL: Windows installers
- https://www.postgresql.org/download/windows

Download PostgreSQL: Open source PostgreSQL packages and installers from EDB
- https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
:::


#### 可能的问题

可能会在安装过程中弹出下面的问题：
> Problem running post-install step. Installation may not complete correctly. The database cluster initialisation failed.

这个一般是因为安装时语言选项选成了 "Chinese"，而一些环境不支持 "GBK" 编码。

所以需要手动初始化数据库：

```sh
initdb -D "E:\postgresql\16\data" -U postgres
```

::: warning See: postgres installation the database cluster initialization failed ( Postgresql Version 9.4.4 ) - Stack Overflow
  * https://stackoverflow.com/questions/32453451/postgres-installation-the-database-cluster-initialization-failed-postgresql-ve
:::

然后启动数据库：

```sh
pg_ctl -D "E:\postgresql\16\data" -l logfile -o "-p 15432" start
```

查看状态：

```sh
pg_ctl -D "E:\postgresql\16\data" status
```

以 `postgres` 用户登录 psql：

```sh
psql --host=127.0.0.1 --port=15432 -U postgres
```

## 卸载

查看已安装的版本：

```sh
ls /usr/lib/postgresql/
```

输出形如：

```sh
14/ 16/
```

然后删除指定版本：

```sh
sudo apt-get autoremove postgresql-14
```

## 指定数据目录

<!-- ```sh
# Create a new directory for the database cluster:
sudo mkdir /var/lib/postgresql/16/main
# Change the owner of the directory to the postgres user:
sudo chown -R postgres:postgres /var/lib/postgresql/16/main
# Initialize the database cluster:
sudo -u postgres /usr/lib/postgresql/16/bin/initdb -D /var/lib/postgresql/16/main
``` -->

## 允许远程访问 postgresql

查看正在监听的端口：

```sh
netstat -nlt
```

查看 postgresql 配置文件路径：

```sh
psql -U postgres -c 'SHOW config_file'
```

输出形如：

```sh
               config_file
-----------------------------------------
 /etc/postgresql/16/main/postgresql.conf
(1 row)
```

修改 `/etc/postgresql/16/main/postgresql.conf`:

```sh
listen_addresses = '*'
```

并在 `/etc/postgresql/16/main/pg_hba.conf` 添加：

```sh
host    all             all              0.0.0.0/0                       md5
host    all             all              ::/0                            md5
```

重启服务:

```sh
sudo systemctl restart postgresql
```

::: tip See:
- https://stackoverflow.com/questions/18580066/how-to-allow-remote-access-to-postgresql-database
- https://www.bigbinary.com/blog/configure-postgresql-to-allow-remote-connection
:::

## 安装 pgvector

```sh
sudo apt install postgresql-server-dev-16
export PG_CONFIG=/Library/PostgreSQL/16/bin/pg_config

git clone --branch v0.6.2 https://github.com/pgvector/pgvector.git
cd pgvector
sudo make
sudo make install
```

::: tip See: Open-source vector similarity search for Postgres
- https://github.com/pgvector/pgvector
:::