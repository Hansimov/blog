# rsync 常用命令

## 从远程主机下载文件到本地指定目录

```sh
rsync -avhP <username>@<remote_host>:<folder>/<filename> ~/downloads/
```

- `-a`：保留属性（时间戳、权限等）
- `-v`：显示详细过程
- `-h`：人类可读大小（MB/GB）
- `-P`：显示进度并支持断点续传