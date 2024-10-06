# 安装 GO

## 下载并解压

::: tip 国内下载源: https://studygolang.com/dl
:::

```sh
cd ~/downloads
wget https://studygolang.com/dl/golang/go1.23.2.linux-amd64.tar.gz
tar zxvf go1.23.2.linux-amd64.tar.gz --one-top-level
cd go1.23.2.linux-amd64
sudo mv go /usr/local
```

## 配置环境变量

在 `.zshrc` 中添加：

```sh
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
```

使配置生效：

```sh
source ~/.zshrc
```

## 验证安装

```sh
go version
```

输出形如：

```sh
go version go1.23.2 linux/amd64
```

## Hello, World!

创建 `hello.go`：

```go
package main

import "fmt"

func main() {
    fmt.Println("Hello, World!")
}
```

运行：

```sh
go run hello.go
```

输出形如：

```sh
Hello, World!
```