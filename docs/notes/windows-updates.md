# Win 10 关闭自动更新

::: tip Win10注册表关闭自动更新方法分享！ - 腾讯云开发者社区 - 腾讯云
* https://cloud.tencent.com/developer/news/988091

通过注册表编辑器关闭Windows自动更新_注册表关闭windows更新 - CSDN博客
* https://blog.csdn.net/xingshanchang/article/details/132824714

Win 10如何使用注册表禁用自动更新-百度经验
* https://jingyan.baidu.com/article/8ebacdf013582f08f65cd58d.html
:::

1. `win` + `r` 打开运行窗口，输入 `regedit`，回车，打开注册表编辑器。
2. 定位到 `HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows`
3. 右键 `Windows`，新建 `项`，命名为 `WindowsUpdate`（若已存在则不必创建）
4. 右键 `WindowsUpdate`，新建 `项`，命名为 `AU`
5. 在 `AU` 右侧空白处，右键新建 `DWORD (32 位) 值`，命名为 `NoAutoUpdate`
6. 双击 `NoAutoUpdate`，修改数值数据为 `1`
7. 重启电脑生效