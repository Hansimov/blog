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

::: tip See: How To Move a PostgreSQL Data Directory to a New Location on Ubuntu 20.04 | DigitalOcean
* https://www.digitalocean.com/community/tutorials/how-to-move-a-postgresql-data-directory-to-a-new-location-on-ubuntu-20-04

How to change PostgreSQL’s data directory on Linux | fitodic’s blog
* https://fitodic.github.io/how-to-change-postgresql-data-directory-on-linux

permissions - Changing Ownership: "Operation not permitted" - even as root! - Ask Ubuntu
* https://askubuntu.com/questions/675296/changing-ownership-operation-not-permitted-even-as-root
:::

### 查看数据目录

```sh
sudo -u postgres psql -c "SHOW data_directory;"
```

输出形如：

```sh
       data_directory
-----------------------------
 /var/lib/postgresql/16/main
(1 row)
```

### 停止服务

```sh
sudo systemctl stop postgresql
```

### 创建并复制新数据目录

假设新的数据目录为 `/media/data1/postgresql/16/main`。

那么创建目录，并赋予 `postgres` 用户权限：

```sh
sudo mkdir -p /media/data1/postgresql/16/main
sudo chown -R postgres:postgres /media/data1/postgresql/16/main
# sudo chown -R postgres:postgres /media/data1/postgresql/16/main
```

如果 `chown` 遇到权限问题，并且 `sudo chattr -i file` 出现 `Operation not supported` 的问题，那么原因出在分区类型是 `ntfs` 或 `fat32`。推荐的解决方案是重新格式化分区为 `ext4`。

::: warning See: permissions - Changing Ownership: "Operation not permitted" - even as root! - Ask Ubuntu
* https://askubuntu.com/questions/675296/changing-ownership-operation-not-permitted-even-as-root

permissions - How do I use 'chmod' on an NTFS (or FAT32) partition? - Ask Ubuntu
* https://askubuntu.com/questions/11840/how-do-i-use-chmod-on-an-ntfs-or-fat32-partition/956072#956072
:::

复制数据目录：

```sh
sudo rsync -av /var/lib/postgresql/16/main/ /media/data1/postgresql/16/main
```

注意 rsync 的语法 `rsync -a src/ dest`，`src` 后面的 `/` 不要漏掉，否则会在 `dest` 下重复创建一个 `src` 目录。

::: tip See: How to rsync a directory to a new directory with different name? - Unix & Linux Stack Exchange
* https://unix.stackexchange.com/questions/178078/how-to-rsync-a-directory-to-a-new-directory-with-different-name
:::

<del>
移动原数据目录，以避免冲突或误操作：（可选）

```sh
sudo mv /var/lib/postgresql/16/main /var/lib/postgresql/16/main.bak
# # move back
# sudo mv /var/lib/postgresql/16/main.bak /var/lib/postgresql/16/main
```
</del>

### 修改 postgresql 配置

配置文件位于 `<data_directory>/postgresql.conf`：

```sh
sudo nano /etc/postgresql/16/main/postgresql.conf
# code /etc/postgresql/16/main/postgresql.conf
```

注释掉原来的数据目录，改成新的数据目录：

```sh
# data_directory = '/var/lib/postgresql/16/main'		# use data in another directory
data_directory = '/media/data1/postgresql/16/main'		# use data in another directory
```

<del>

### 修改 systemd 配置

修改 `/lib/systemd/system/postgresql.service`：

```sh
sudo nano /lib/systemd/system/postgresql.service
# code /lib/systemd/system/postgresql.service
```

添加内容：

```sh
[Service]
...
Environment=PGDATA=/media/data1/postgresql/16/main
```

重新加载 systemd 配置：

```sh
sudo systemctl daemon-reload
```

</del>

### 重启服务

```sh
sudo systemctl restart postgresql
```

查看服务状态：

```sh
sudo systemctl status postgresql
```

查看数据目录是否正确：

```sh
sudo -u postgres psql -c "SHOW data_directory;"
```

输出形如：

```sh
         data_directory
---------------------------------
 /media/data1/postgresql/16/main
(1 row)
```

### 常见问题

可能遇到无法正常启动的问题，一般可能是：
1. `systemd` 的 `Environment` 没有配置好，建议重新配置和重启 `systemd`（[见上](#修改-systemd-配置)）。
2. 重启 `postgresql` 服务时，没有正确停止服务，可以尝试 `sudo systemctl stop postgresql` 后再重启。
3. 硬盘没有正确配置好，可以尝试重启系统，并重新格式化硬盘。

::: warning See: Can not connect to PostgreSQL listening on port 5432 - Ask Ubuntu
* https://askubuntu.com/questions/50621/can-not-connect-to-postgresql-listening-on-port-5432
:::

## 查看监听端口和配置文件

查看正在监听的端口：

```sh
netstat -nlt
```

查看配置文件路径：

```sh
sudo -u postgres psql -c "SHOW config_file;"
```

输出形如：

```sh
               config_file
-----------------------------------------
 /etc/postgresql/16/main/postgresql.conf
(1 row)
```


## 允许远程访问 postgresql

修改配置文件 `/etc/postgresql/16/main/postgresql.conf`:

```sh
listen_addresses = '*'
```

注意这里是 `'*'` 而不是 `"*"`。

然后（这里需要 root 权限才能打开）：

```sh
sudo nano /etc/postgresql/16/main/pg_hba.conf`
```

添加：

```sh
host    all             all             0.0.0.0/0               md5
host    all             all             ::/0                    md5
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

git clone --branch v0.6.2 https://githubfast.com/pgvector/pgvector.git
cd pgvector
sudo make
sudo make install
```

::: tip See: Open-source vector similarity search for Postgres
- https://github.com/pgvector/pgvector
:::