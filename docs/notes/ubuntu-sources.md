# Ubuntu 换国内源

::: tip Ubuntu - USTC Mirror Help
* https://mirrors.ustc.edu.cn/help/ubuntu.html#__tabbed_6_1
:::

```sh
sudo nano /etc/apt/sources.list
```

添加下列内容：（清华源/中科大源）

```sh
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy main restricted universe multiverse
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-updates main restricted universe multiverse
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-backports main restricted universe multiverse
# deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ jammy-security main restricted universe multiverse

deb https://mirrors.ustc.edu.cn/ubuntu jammy main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu jammy-updates main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu jammy-backports main restricted universe multiverse
deb https://mirrors.ustc.edu.cn/ubuntu jammy-security main restricted universe multiverse

# 注释掉原有的源
# deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
# deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
# deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
# deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
```

更新源：

```sh
sudo apt-get update
```

::: tip See: Ubuntu更换国内源的方法：Ubuntu22.04 LTS 清华源 阿里源 中科大源 163源
- https://www.ufans.top/index.php/archives/461/
:::