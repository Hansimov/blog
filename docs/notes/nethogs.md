# 安装 nethogs（查看 Linux 进程网速）

::: tip raboof/nethogs: Linux 'net top' tool
* https://github.com/raboof/nethogs#on-debian
:::

## 安装

```sh
sudo apt-get install build-essential libncurses5-dev libpcap-dev
git clone https://github.com/raboof/nethogs
```

```sh
cd nethogs
make
sudo make install
hash -r
```

## 运行

```sh
sudo nethogs
```

输出形如：
    
```sh
NetHogs version 0.8.7-44-g0fe341e

    PID USER     PROGRAM                DEV         SENT      RECEIVED
 721311 user     BBDown                 eno1      113.872    6109.553 kB/s
 575365 user     python                 eno1       47.732     843.555 kB/s
1498334 user     python                 eno1        4.900      87.813 kB/s
 702316 user     sshd: user@pts/23      eno1        2.913       1.182 kB/s
      ? root     unknown TCP                        0.251       0.268 kB/s
    ...
  TOTAL                                           169.678    7042.371 kB/s
```