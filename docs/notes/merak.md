# 使用 Merak 组网

## Linux 使用 Merak 服务

使用 `linux-amd64` 版本。
- 将文件 `merak-service` 复制到目标路径。
- 将 `<CONFIG_HASH>.yml` 配置文件也放到同一路径下。

注册：

```sh
sudo ./merak-service -service install -config "<FULL_PATH>/<CONFIG_HASH>.yml"
```

运行：

```sh
sudo systemctl enable Merak && sudo systemctl start Merak
# sudo ./merak-service -service run -config "<FULL_PATH>/<CONFIG_HASH>.yml"
```

重启：

```sh
sudo systemctl restart Merak
# sudo ./merak-service -service restart
```

查看服务状态：

```sh
sudo systemctl status Merak
```

## Windows 使用 Merak 服务

使用 `windows-amd64` 版本。
- 将文件 `merak-service.exe` 复制到目标路径。
- 将 `<CONFIG_HASH>.yml` 配置文件也放到同一路径下。

安装：

```sh
merak-service.exe -service install -config "<FULL_PATH>\<CONFIG_HASH>.yml"
```

运行：

```sh
merak-service.exe -service run -config "<FULL_PATH>\<CONFIG_HASH>.yml"
```

启动：

```sh
merak-service.exe -service start
```