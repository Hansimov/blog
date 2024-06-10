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

### 查看配置

```sh
\dconfig
```

查看某项具体配置：

```sh
\dconfig shared_buffers
```


## 显示

### 切换行列显示

```sh
\x
```

### 切换表头显示

```sh
\t
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

## 数据库

### 创建数据库

```sql
CREATE DATABASE [database];
```

### 切换数据库
```sql
\c [database]
```

### 重命名数据库

与目标数据库断开连接（连到默认的 postgres 数据库）：

```sql
\c postgres
```

关闭目标数据库的所有连接：

```sql
REVOKE CONNECT ON DATABASE [db_name] FROM public;
```

```sql
SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '[db_name]';
```

重命名：

```sql
ALTER DATABASE [db_name] RENAME TO [new_db_name];
```

::: tip See: sql - PostgreSQL - Rename database - Stack Overflow
* https://stackoverflow.com/questions/143756/postgresql-rename-database

Postgresql - unable to drop database because of some auto connections to DB - Stack Overflow  
* https://stackoverflow.com/questions/17449420/postgresql-unable-to-drop-database-because-of-some-auto-connections-to-db
:::


### 列出库中所有表

切换到目标库：

```sql
\c [database]
```

列出表：

```sql
\dt
```

### 查看库中活动

```sh
select pg_blocking_pids(pid) as block_pid, pid, (now()-xact_start) as elapsed, wait_event, wait_event_type, substr(query,1,100) as query from pg_stat_activity where state <> 'idle' order by 3 desc;
```

::: tip See: 如何解决PostgreSQL执行语句长时间卡着不动不报错也不执行的问题_PostgreSQL_脚本之家
* https://www.jb51.net/database/315035mbl.htm

PostgreSQL: Documentation: 16: 28.2. The Cumulative Statistics System
* https://www.postgresql.org/docs/current/monitoring-stats.html#MONITORING-PG-STAT-ACTIVITY-VIEW
:::

## 表

### 查看表

```sql
SELECT * FROM [table] LIMIT 10;
```

### 查看表结构
  
```sql
SELECT column_name, data_type FROM information_schema.columns WHERE table_name = '[table_name]';
```

::: tip See: sql - How to get a list column names and datatypes of a table in PostgreSQL? - Stack Overflow
* https://stackoverflow.com/questions/20194806/how-to-get-a-list-column-names-and-datatypes-of-a-table-in-postgresql
:::

### 删除表

```sql
DROP TABLE [table];
```

### 统计行数

```sql
SELECT COUNT(*) FROM [table];
```

::: tip See: How to show data in a table by using psql command line interface? - Stack Overflow
* https://stackoverflow.com/questions/26040493/how-to-show-data-in-a-table-by-using-psql-command-line-interface

postgresql - Alternate output format for psql showing one column per line with column name - Stack Overflow
* https://stackoverflow.com/questions/9604723/alternate-output-format-for-psql-showing-one-column-per-line-with-column-name
:::

## 实用场景

### 添加主键

假如想将 `bvid`（可能有重复）添加为 `videos` 表的主键。

首先创建临时表，选出最早插入的 bvid：

```sql
CREATE TEMPORARY TABLE temp_table AS SELECT MIN(ctid) as min_ctid, bvid FROM videos GROUP BY bvid;
```

然后删除原表中不在临时表中的行：
- 如果这一步耗时很长，大概率是语句写得不好，尽量使用 JOIN 思想

```sql
-- DELETE FROM videos where ctid not in (select min_ctid from temp_table); -- 这种写法非常慢
DELETE FROM videos USING temp_table WHERE videos.ctid <> temp_table.min_ctid AND videos.bvid = temp_table.bvid;
```

最后将 `bvid` 设为主键：

```sql
ALTER TABLE videos ADD PRIMARY KEY (bvid);
```

最后删除临时表：

```sql
DROP TABLE temp_table;
```

### 插入或更新

有如下表：

```sql
create table temp_table (bvid text primary key, title text);
```

插入或更新：

```sql
INSERT INTO temp_table (bvid, title) VALUES ('b1', 'title of b1'), ('b2', 'title of b2') ON CONFLICT (bvid) DO UPDATE SET title = EXCLUDED.title;
```


::: tip See: PostgreSQL UPSERT Statement
* https://www.postgresqltutorial.com/postgresql-tutorial/postgresql-upsert/
:::

### 取回数据显示行号

例如，取出 `videos` 表中 `mid` 为 946974 的最新 30 条数据，并显示行号：

```sql
select ROW_NUMBER() OVER (ORDER BY pubdate DESC) as row_num, pubdate, title from (select pubdate, title from videos where mid = 946974 ORDER BY pubdate DESC LIMIT 30);
```

### 选取某个组合的数据

例如，取出 `videos` 表中 `mid` 为 `946974` 且 `tid` 的 `main_r_key` 为 `knowledge` 的数据：

```sql
SELECT pubdate, title, tname, insert_at FROM videos v JOIN regions r ON v.tid = r.r_tid WHERE v.mid = '946974' AND r.main_r_key = 'knowledge' ORDER BY pubdate DESC;
```

## 性能分析和优化

::: tip Tuning Your PostgreSQL Server - PostgreSQL wiki
* https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server
:::

### 使用 postgresqltuner

::: tip jfcoz/postgresqltuner: Simple script to analyse your PostgreSQL database configuration, and give tuning advice
  * https://github.com/jfcoz/postgresqltuner
:::

安装：

```sh
sudo apt install libdbd-pg-perl libdbi-perl perl-modules
curl -o postgresqltuner.pl -L https://raw.staticdn.net/jfcoz/postgresqltuner/master/postgresqltuner.pl
chmod +x postgresqltuner.pl
```

运行：

```sh
./postgresqltuner.pl --host=<hostname> --database=<dbname> --user=<username> --password=<password>
```

### 修改 shared_buffers 和 effective_cache_size

查看 postgresql 配置文件路径：

```sh
sudo -u postgres psql -c "SHOW config_file;"
```

编辑 postgresql 配置文件：

```sh
sudo nano /etc/postgresql/16/main/postgresql.conf
```

修改如下行：（假设内存为 128GB）

```sh
# typically 25% of total memory
shared_buffers = 32GB                   # min 128kB, default 128MB
                                        # (change requires restart)

work_mem = 1GB                          # min 64kB, default 4MB

# typically 50% of total memory
effective_cache_size = 64GB             # default 4GB
```

重启服务：

```sh
sudo systemctl restart postgresql
```