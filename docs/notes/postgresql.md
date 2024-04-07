# Postgresql installation and setup

## Ubuntu

### Install postgresql

(Optional) Preparation:

```sh
# Create the file repository configuration:
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# Import the repository signing key:
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
# Update the package lists:
sudo apt-get update
```

Install:

```sh
# Install the latest version of PostgreSQL.
# If you want a specific version, use 'postgresql-12' or similar instead of 'postgresql':
sudo apt-get -y install postgresql
```

::: tip See:
- https://www.postgresql.org/download/linux/ubuntu
- https://ubuntu.com/server/docs/databases-postgresql
:::

### Install pgvector

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


### Allow remote access to postgresql

View running ports:

```sh
netstat -nlt
```

Show postgresql config file path:

```sh
psql -U postgres -c 'SHOW config_file'
```

Should output:

```sh
               config_file
-----------------------------------------
 /etc/postgresql/16/main/postgresql.conf
(1 row)
```

Modify `/etc/postgresql/16/main/postgresql.conf`:

```sh
listen_addresses = '*'
```

Add following rows to `/etc/postgresql/16/main/pg_hba.conf`:

```sh
host    all             all              0.0.0.0/0                       md5
host    all             all              ::/0                            md5
```

Restart service:

```sh
sudo systemctl restart postgresql
```

::: tip See:
- https://stackoverflow.com/questions/18580066/how-to-allow-remote-access-to-postgresql-database
- https://www.bigbinary.com/blog/configure-postgresql-to-allow-remote-connection
:::


## Windows

### Install postgresql

Click, download and install:

- https://sbp.enterprisedb.com/getfile.jsp?fileid=1258893

Suppose the postgresql is installed in `D:\postgresql\16`.

Then add `D:\postgresql\16\bin` to system `PATH`.

::: tip See: PostgreSQL: Windows installers
- https://www.postgresql.org/download/windows

Download PostgreSQL: Open source PostgreSQL packages and installers from EDB
- https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
:::

### Common issue

You might encounter following Warning message during installation:
> Problem running post-install step. Installation may not complete correctly. The database cluster initialisation failed.

This might because you select "Chinese" in language option during installation, which does not support "GBK" as the encoding of server.

Then you could run following command to initialize the database manually:

```sh
initdb -D "E:\postgresql\16\data" -U postgres
```

::: tip See: postgres installation the database cluster initialization failed ( Postgresql Version 9.4.4 ) - Stack Overflow
  * https://stackoverflow.com/questions/32453451/postgres-installation-the-database-cluster-initialization-failed-postgresql-ve
:::


### Start service

After `initdb` in above step, you can then start database service with:

```sh
pg_ctl -D "E:\postgresql\16\data" -l logfile -o "-p 15432" start
```

See status:

```sh
pg_ctl -D "E:\postgresql\16\data" status
```

Login interactive interface as `postgres`:

```sh
psql --host=127.0.0.1 --port=15432 -U postgres
```