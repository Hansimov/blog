# 安装 MinIO

::: tip minio/minio
* https://github.com/minio/minio#gnulinux

Configuring MinIO with SystemD
* https://blog.min.io/configuring-minio-with-systemd
:::

## 下载运行

```sh
cd ~/downloads
wget https://dl.min.io/server/minio/release/linux-amd64/minio
chmod +x minio
sudo cp minio /usr/local/bin/
# minio server /media/data/minio --console-address ":9001"
```

## 创建用户和目录

```sh
sudo groupadd -r minio-user
sudo useradd -M -r -g minio-user minio-user
sudo mkdir -p /media/data/minio
sudo chown minio-user:minio-user /media/data/minio
```

## 配置环境

```sh
sudo nano /etc/default/minio
```

添加如下内容：

```bash
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin
MINIO_VOLUMES="/media/data/minio"
MINIO_OPTS="--console-address :9001"
```

## 添加到系统服务

```sh
sudo nano /etc/systemd/system/minio.service
```

添加如下内容：

```ini
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local/

User=minio-user
Group=minio-user
ProtectProc=invisible

EnvironmentFile=/etc/default/minio
ExecStartPre=/bin/bash -c "if [ -z \"${MINIO_VOLUMES}\" ]; then echo \"Variable MINIO_VOLUMES not set in /etc/default/minio\"; exit 1; fi"
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES

Restart=always
LimitNOFILE=65536
TasksMax=infinity
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
```

启用服务：

```sh
sudo systemctl daemon-reload
```

```sh
sudo systemctl enable minio.service
```

```sh
sudo systemctl start minio.service
```

```sh
sudo systemctl status minio.service
```

查看日志：

```sh
journalctl -u minio.service -f
```

## 访问 MinIO

- API: `http://localhost:9000`
- 控制台: `http://localhost:9001`
- 用户: `minioadmin`
- 密码: `minioadmin`

## 安装命令行工具 mc

::: tip MinIO Client — MinIO Object Storage (AGPLv3)
* https://docs.min.io/community/minio-object-store/reference/minio-mc.html#install-mc
:::

```sh
cd ~/downloads
curl https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
chmod +x mc
sudo cp mc /usr/local/bin/
```

## mc 连接 minio 服务

```sh
mc alias set myminio http://localhost:9000 minioadmin minioadmin
```

```sh
mc ls myminio
```