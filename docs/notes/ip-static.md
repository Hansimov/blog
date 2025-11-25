# 设置静态 IP

```sh
# 查看连接名称
nmcli connection show

# 假如输出 Name: Wired connection 2
# 选择 DEVICE 有值的那行（形如enp10s18）对应的 NAME
CONN_NAME="Wired connection 1"
# CONN_NAME="Wired connection 2"

# 设置IP
IP_ADDR="192.168.31.122/24"
IP_GATE="192.168.31.1"
sudo nmcli connection modify "$CONN_NAME" ipv4.addresses $IP_ADDR ipv4.gateway $IP_GATE ipv4.dns $IP_GATE ipv4.method manual

# 重启连接以使设置生效
sudo nmcli connection down "$CONN_NAME" && sudo nmcli connection up "$CONN_NAME"
```