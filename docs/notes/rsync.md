# rsync 常用命令

## 从远程主机下载文件到本地指定目录

```sh
rsync -avhP <username>@<remote_host>:<folder>/<filename> ~/downloads/
```

- `-a`：保留属性（时间戳、权限等）
- `-v`：显示详细过程
- `-h`：人类可读大小（MB/GB）
- `-P`：显示进度并支持断点续传

## 上传文件到远程主机指定目录指定文件

将本地 `*_*.py` 文件上传到远程主机 `ai` 的指定目录：

```sh
LOCAL_DIR="<local_dir>"
FILE_PATTERN="*_*.py"
REMOTE_HOST="ai"
REMOTE_DIR="<remote_dir>"

# sudo apt install sshpass
sshpass -p "${SUDOPASS}" rsync -avz --progress ${LOCAL_DIR}/${FILE_PATTERN} ${REMOTE_HOST}:${REMOTE_DIR}/
echo "Synced at $(date +'%H:%M:%S')"
```

## 从远程主机同步文件到本地

将远程主机 `ai` 的 `cli.log` 文件同步到本地目录并重命名为 `machine.log`：

```sh
REMOTE_HOST="ai"
REMOTE_DIR="<remote_dir>"
REMOTE_FILE="cli.log"
LOCAL_DIR="<local_dir>"
LOCAL_FILE="machine.log"

# sudo apt install sshpass
sshpass -p "${SUDOPASS}" rsync -avz --progress ${REMOTE_HOST}:${REMOTE_DIR}/${REMOTE_FILE} ${LOCAL_DIR}/${LOCAL_FILE}
echo "Synced at $(date +'%H:%M:%S')"
```