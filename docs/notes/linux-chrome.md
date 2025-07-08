# Linux 安装 Chrome 和 ChromeDriver

::: tip Chrome for Testing availability
* https://googlechromelabs.github.io/chrome-for-testing/#stable
:::

## 安装 Chrome

```sh
cd downloads
curl -L --proxy http://127.0.0.1:11111 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o google-chrome-stable_current_amd64.deb
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
Google Chrome 138.0.7204.92
```

更新版本：

```sh
sudo apt install --only-upgrade google-chrome-stable
```

卸载：

```sh
sudo apt purge google-chrome-stable
```

## 安装 ChromeDriver

```sh
cd downloads
CHROME_VERSION=$(google-chrome --version | awk '{print $3}')
curl -L --proxy http://127.0.0.1:11111 https://storage.googleapis.com/chrome-for-testing-public/$CHROME_VERSION/linux64/chromedriver-linux64.zip -o chromedriver-linux64.zip
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
ChromeDriver 138.0.7204.92 (f079b9bc781e3c2adb1496ea1d72812deb0ddb3d-refs/branch-heads/7204_50@{#8})
```