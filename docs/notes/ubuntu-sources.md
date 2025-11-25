# Ubuntu 换国内源

::: tip Ubuntu - USTC Mirror Help
* https://mirrors.ustc.edu.cn/help/ubuntu.html#__tabbed_6_1

Ubuntu更换国内源的方法：Ubuntu22.04 LTS 清华源 阿里源 中科大源 163源
- https://www.ufans.top/index.php/archives/461/
:::

## 【首选】命令行

```sh
sudo sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list

# 一般不建议替换 security 源
# 镜像站同步有延迟，可能会导致生产环境不能及时安装上最新的安全更新
sudo sed -i 's/security.ubuntu.com/mirrors.ustc.edu.cn/g' /etc/apt/sources.list

# 使用 HTTPS 避免运营商缓存劫持
sudo sed -i 's/http:/https:/g' /etc/apt/sources.list
```

## 【次选】手动修改文件

```sh
sudo nano /etc/apt/sources.list
```

修改为如下内容：

<<< @/notes/configs/sources.list{ini}


## 更新源

```sh
sudo apt-get update
```

