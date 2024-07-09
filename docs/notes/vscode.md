# VSCode 的一些坑

## Remote SSH - 卡在 Download VSCode Server

```sh
ls ~/.vscode-server/bin
```

会列出安装包的哈希值，形如：

```sh
8b3775030ed1a69b13e4f4c628c612102e30a681
```

删除这些已有的安装包：

```sh
rm -rf ~/.vscode-server/bin
```

将对应的哈希填入，下载安装：
- https://update.code.visualstudio.com/commit:{COMMIT_HASH}/server-linux-x64/stable

或者直接在命令行下载：

```sh
wget --content-disposition https://update.code.visualstudio.com/commit:8b3775030ed1a69b13e4f4c628c612102e30a681/server-linux-x64/stable
```

拷贝并解压压缩包，重命名为哈希值：

```sh
cp vscode-server-linux-x64.tar.gz ~/.vscode-server/bin/
cd ~/.vscode-server/bin/
tar -zxf vscode-server-linux-x64.tar.gz
mv vscode-server-linux-x64 8b3775030ed1a69b13e4f4c628c612102e30a681
```

最后在本地 VSCode 重新运行 `Remote SSH: Connect to Host` 即可。

::: tip vs code连接服务器卡在Downloading VS Code Server - MissSimple - 博客园
* https://www.cnblogs.com/c-rex/p/16265570.html
:::

## .yml 被强制缩进 4 个空格

删掉 `settings.json` 中的这行：

```json
"prettier.tabWidth": 4
```
