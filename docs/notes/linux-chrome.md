# Linux 安装 Chrome 和 ChromeDriver

::: tip Chrome for Testing availability
* https://googlechromelabs.github.io/chrome-for-testing/#stable
:::

## 安装 Chrome

```sh
cd downloads

# curl -L --proxy http://127.0.0.1:11111 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o google-chrome-stable_current_amd64.deb

# sudo apt install -y aria2
aria2c --all-proxy=http://127.0.0.1:11111 -x 16 -s 16 -k 1M -o google-chrome-stable_current_amd64.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

sudo apt update
sudo apt install ./google-chrome-stable_current_amd64.deb
```

查看路径：

```sh
which google-chrome
```

输出形如：

```sh
/bin/google-chrome
```

查看版本：

```sh
google-chrome --version
```

输出形如：

```sh
Google Chrome 143.0.7499.169
```

更新版本：

```sh
sudo apt install --only-upgrade google-chrome-stable
```

卸载：

```sh
sudo apt purge google-chrome-stable
```

## 运行 Chrome

```sh
google-chrome --proxy-server="http://127.0.0.1:11111"
```

## 安装 ChromeDriver

```sh
cd downloads
CHROME_VERSION=$(google-chrome --version | awk '{print $3}')

# curl -L --proxy http://127.0.0.1:11111 https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chromedriver-linux64.zip -o chromedriver-linux64.zip

aria2c --all-proxy=http://127.0.0.1:11111 -x 16 -s 16 -k 1M -o chromedriver-linux64.zip "https://storage.googleapis.com/chrome-for-testing-public/${CHROME_VERSION}/linux64/chromedriver-linux64.zip"

unzip chromedriver-linux64.zip
sudo cp chromedriver-linux64/chromedriver /usr/local/bin/
```

查看路径：

```sh
which chromedriver
```

输出形如：

```sh
/usr/local/bin/chromedriver
```

查看版本：

```sh
chromedriver --version
```

输出形如：

```sh
ChromeDriver 143.0.7499.169 (164b20aab62509dad21fd46383951aeec084ad1e-refs/branch-heads/7499@{#3399})
```


## 常见问题

### 安装依赖

```sh
sudo apt-get install xvfb xserver-xephyr tigervnc-standalone-server x11-utils gnumeric
```


### Missing X server or $DISPLAY

命令行报错类似：

```sh
Missing X server or $DISPLAY
The platform failed to initialize.  Exiting.
```

一般发生在 ssh 连接意外断开之后。

一般情况下，`$DISPLAY` 默认为 `localhost:11.0`。

解决方法是正确设置 `$DISPLAY` 环境变量。

#### 方案 1

```sh
# xdpyinfo -display :10.0
export DISPLAY=localhost:10.0
```

如果服务器重启或者重连 ssh，可能需要重置 `$DISPLAY`：

```sh
# xdpyinfo -display :11.0
export DISPLAY=localhost:11.0
```

> [!NOTE]
> [Bug]: Missing X server or $DISPLAY · Issue #8148 · puppeteer/puppeteer
>   * https://github.com/puppeteer/puppeteer/issues/8148
>   * https://github.com/puppeteer/puppeteer/issues/8148#issuecomment-3095573227

#### 方案 2

```sh
# sudo apt-get install -y xvfb
# sudo apt-get -y install xorg xvfb gtk2-engines-pixbuf dbus-x11 xfonts-base xfonts-100dpi xfonts-75dpi xfonts-cyrillic xfonts-scalable
```

```sh
Xvfb -ac :99 -screen 0 1280x1024x16 &
export DISPLAY=:99
```

这会在端口 `:99` 启动一个虚拟显示器，但对通过 ssh 连接的用户是不可见的。

> [!NOTE] 
> ssh - Unable to open X display when trying to run google-chrome on Centos (Rhel 7.5) - Stack Overflow
>   * https://stackoverflow.com/questions/60304251/unable-to-open-x-display-when-trying-to-run-google-chrome-on-centos-rhel-7-5


### D-Bus connection was disconnected

命令行报错类似：

```txt
D-Bus connection was disconnected. Aborting.
```

查看当前 D-Bus 地址：

```sh
echo $DBUS_SESSION_BUS_ADDRESS
# unix:path=/run/user/1000/bus
```

修改为 `none`：

```sh
export DBUS_SESSION_BUS_ADDRESS=none
```

### Python 程序中调用 Chrome

```sh
# Xvfb -ac :99 -screen 0 1280x1024x16 &
export DISPLAY=:99 DBUS_SESSION_BUS_ADDRESS=none
```

或者：

```sh
DISPLAY=:99 DBUS_SESSION_BUS_ADDRESS=none python -m ...
```