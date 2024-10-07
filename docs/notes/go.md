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
export GOPROXY="https://mirrors.aliyun.com/goproxy,direct"
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

## VSCode 设置

```json
    "[go]": {
        "editor.formatOnSave": true,
        "editor.insertSpaces": true,
        "editor.tabSize": 4,
        "editor.codeActionsOnSave": {
            "source.fixAll": "never",
            "source.organizeImports": "never"
        }
    },
```

::: warning 如果 VSCode 里的 GO 插件很卡， 大概率就是没有配置 `editor.codeActionsOnSave`。
:::

## 安装包

确保添加了国内源：

```sh
export GOPROXY="https://mirrors.aliyun.com/goproxy,direct"
```

查看是否配置成功：

```sh
go env | grep GOPROXY
```

输出形如：

```sh
GOPROXY='https://mirrors.aliyun.com/goproxy,direct'
```

然后安装包。例如安装 VSCode 中 GO 插件需要的包：

```sh
go install golang.org/x/tools/gopls@latest
go install honnef.co/go/tools/cmd/staticcheck@latest
# go install github.com/cweill/gotests/gotests@v1.6.0
# go install github.com/fatih/gomodifytags@v1.17.0
# go install github.com/josharian/impl@v1.4.0
# go install github.com/go-delve/delve/cmd/dlv@latest
```

查看是否安装：

```sh
ls ~/go/bin/
```