# 安装 Grafana

::: tip Download Grafana | Grafana Labs
* https://grafana.com/grafana/download

Start the Grafana server | Grafana documentation
* https://grafana.com/docs/grafana/latest/setup-grafana/start-restart-grafana/#start-the-grafana-server-using-initd
:::

## Ubuntu 安装 Grafana

```sh
sudo apt-get install -y adduser libfontconfig1 musl
cd ~/downloads
curl -L --proxy httpL://127.0.0.1:11111 https://dl.grafana.com/enterprise/release/grafana-enterprise_12.0.1_amd64.deb -o grafana-enterprise_12.0.1_amd64.deb
sudo dpkg -i grafana-enterprise_12.0.1_amd64.deb
```

### 启动 Grafana

```sh
sudo systemctl daemon-reload
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

- 默认端口：`3000`
- 默认用户名：`admin`
- 默认密码：`admin`


查看服务状态：

```sh
sudo systemctl status grafana-server
```

## Ubuntu 安装 node_exporter

::: tip prometheus/node_exporter: Exporter for machine metrics
* https://github.com/prometheus/node_exporter
* https://github.com/prometheus/node_exporter/releases

Monitoring Linux host metrics with the Node Exporter | Prometheus
* https://prometheus.io/docs/guides/node-exporter
:::

```sh
cd ~/downloads
NODE_EXPORTER_VERSION=1.9.1
NODE_EXPORTER_FILE=node_exporter-1.9.1.linux-amd64.tar.gz
curl -L --proxy http://127.0.0.1:11111 https://github.com/prometheus/node_exporter/releases/download/v$NODE_EXPORTER_VERSION/$NODE_EXPORTER_FILE -o $NODE_EXPORTER_FILE
tar xvfz $NODE_EXPORTER_FILE
cd $(basename $NODE_EXPORTER_FILE .tar.gz)
```

### 启动 node_exporter

直接启动：

```sh
./node_exporter
```

- 默认端口：`9100`


### 注册 node_exporter 为服务

```sh
# 在 node_exporter 目录下
sudo useradd --no-create-home --shell /usr/sbin/nologin node_exporter
sudo mkdir /etc/node_exporter
sudo chown node_exporter:node_exporter /etc/node_exporter
sudo cp node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
```

创建服务文件：

`sudo nano /etc/systemd/system/node_exporter.service`:

```ini
[Unit]
Description=Prometheus Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

注册服务并启动：

```sh
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
```

### 查看 node_exporter 服务状态

```sh
sudo systemctl status node_exporter
```

测试：

```sh
curl http://localhost:9100/metrics | grep "cpu=\"0\""
```

## Ubuntu 安装 Prometheus

::: tip Releases · prometheus/prometheus
* https://github.com/prometheus/prometheus/releases
:::

```sh
cd ~/downloads
PROMETHEUS_VERSION=3.4.1
PROMETHEUS_FILE=prometheus-3.4.1.linux-amd64.tar.gz
curl -L --proxy http://127.0.0.1:11111 https://github.com/prometheus/prometheus/releases/download/v$PROMETHEUS_VERSION/$PROMETHEUS_FILE -o $PROMETHEUS_FILE
tar xvf $PROMETHEUS_FILE
cd $(basename $PROMETHEUS_FILE .tar.gz)
```

### 启动 Prometheus

创建配置文件：

```sh
cp prometheus.yml prometheus.yml.bak
nano prometheus.yml
```

```yaml
global:
  scrape_interval: 3s

scrape_configs:
- job_name: node
  static_configs:
  - targets: ['localhost:9100']
```

直接启动：

```sh
./prometheus --config.file=./prometheus.yml
```

### 注册 Prometheus 为服务

```sh
# 在 prometheus 目录下
sudo useradd --no-create-home --shell /usr/sbin/nologin prometheus
sudo mkdir /etc/prometheus
sudo mkdir /var/lib/prometheus
sudo cp prometheus.yml /etc/prometheus/
sudo cp prometheus promtool /usr/local/bin/
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown prometheus:prometheus /var/lib/prometheus
```

创建服务文件：

`sudo nano /etc/systemd/system/prometheus.service`

```ini
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
  --config.file /etc/prometheus/prometheus.yml \
  --storage.tsdb.path /var/lib/prometheus/

[Install]
WantedBy=multi-user.target
```

注册服务并启动：

```sh
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus
```

### 查看 Prometheus 服务状态

```sh
sudo systemctl status prometheus
```

## Grafana 添加数据源和面板

- 访问 `http://localhost:3000`，登录
- Connections > Data sources，选择 Prometheus，填写 URL 为 `http://localhost:9090`，点击 Save & Test
- 在右上角选择 Import dashboard，输入 `1860`，选择数据源为 `Prometheus`，点击 Import

### 常用 Dashboards
::: tip Grafana Dashboards
- https://grafana.com/grafana/dashboards
:::

* Node Exporter Full | Grafana Labs
  * https://grafana.com/grafana/dashboards/1860-node-exporter-full