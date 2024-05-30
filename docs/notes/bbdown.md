# 安装 BBDown

::: tip See: nilaoda/BBDown: Bilibili Downloader. 一款命令行式哔哩哔哩下载器.
* https://github.com/nilaoda/BBDown
:::

## 下载安装 ffmpeg

```sh
sudo apt install ffmpeg
```

## 下载安装 BBDown

```sh
wget https://githubfast.com/nilaoda/BBDown/releases/download/1.6.2/BBDown_1.6.2_20240512_linux-x64.zip
unzip BBDown_1.6.2_20240512_linux-x64.zip BBDown
chmod +x BBDown
cp BBDown /usr/bin/BBDown
```

## 使用

### 查看视频信息
```sh
BBDown -c "SESSDATA=..." [BVID] -info
```