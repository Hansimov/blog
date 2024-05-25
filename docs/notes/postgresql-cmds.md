# 常用 postgresql 操作

## 界面

### 进入 psql 界面

```sh
sudo -u postgres psql
```

### 在 shell 中执行 psql 命令

```sh
sudo -u postgres psql -c "[your_sql_command];"
```

### 列出连接信息

```sh
\conninfo
```

输出形如：

```sh
You are connected to database "postgres" as user "postgres" via socket in "/var/run/postgresql" at port "5433".
```


::: tip See: postgresql - Find the host name and port using PSQL commands - Stack Overflow
  * https://stackoverflow.com/questions/5598517/find-the-host-name-and-port-using-psql-commands
:::

### 查看端口

```sh
sudo netstat -plunt | grep postgres
```

## 用户

### 创建新用户

```sh
sudo -u postgres createuser [user]
```

或者在 psql 中创建：

```sql
CREATE USER [user];
```

### 修改密码
    
```sql
ALTER USER [user] WITH PASSWORD '[password]';
```

### 列出所有用户

```sql
\du+
```

::: tip See: How to Create a Postgres User
  * https://phoenixnap.com/kb/postgres-create-user

How can I change a PostgreSQL user password? - Stack Overflow
  * https://stackoverflow.com/questions/12720967/how-can-i-change-a-postgresql-user-password
:::

## 数据

### 创建数据库

```sql
CREATE DATABASE [database];
```

### 切换数据库
```sql
\c [database]
```

### 查看 table

```sh
SELECT * FROM [table] LIMIT 10;
```

### 计数

```sh
SELECT COUNT(*) FROM [table];
```

::: tip See: How to show data in a table by using psql command line interface? - Stack Overflow
* https://stackoverflow.com/questions/26040493/how-to-show-data-in-a-table-by-using-psql-command-line-interface

postgresql - Alternate output format for psql showing one column per line with column name - Stack Overflow
* https://stackoverflow.com/questions/9604723/alternate-output-format-for-psql-showing-one-column-per-line-with-column-name
:::