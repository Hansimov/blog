# 使用 tmpfs 加速文件读写


创建挂载点：

```sh
sudo mkdir -p /mnt/ramdisk
```

挂载 tmpfs：

```sh
sudo mount -t tmpfs -o size=200G tmpfs /mnt/ramdisk
```

复制文件到 tmpfs：

```sh
# sudo makdir -p /mnt/ramdisk/tembed
sudo rsync -a --info=progress2 /media/data/tembed/ /mnt/ramdisk/tembed/
```

复制完整文件夹：

```sh
sudo rsync -a --info=progress2 /media/data/tembed/filename /mnt/ramdisk/tembed/
```

