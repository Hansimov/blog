# 允许新版 Chrome 使用旧版插件

::: tip Chrome插件不能用，这些扩展程序不再受支持，因此已停用，25年7月12日更新！ - 知乎
https://zhuanlan.zhihu.com/p/1927399384947065539
:::

## >= 140 版本

在快捷方式后面加上参数：
```sh
--disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled
```

具体操作：右键 图标 > 更多 > 打开文件位置，右键 快捷方式 > 属性 > 目标，设置为：

```sh
"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" --disable-features=ExtensionManifestV2Unsupported,ExtensionManifestV2Disabled
```

## < 140 版本

1. 将浏览器更新到最新版，确保在 `v138.0.7204.101`（含）以上
2. 下列选项设为 `Enabled`，然后重启 Chrome 以使设置生效
   ```sh
   chrome://flags/#temporary-unexpire-flags-m137
   ```

4. 下列选项设为 `Disabled`

   ```sh
   chrome://flags/#extension-manifest-v2-deprecation-warning
   chrome://flags/#extension-manifest-v2-deprecation-disabled
   chrome://flags/#extension-manifest-v2-deprecation-unsupported
   ```
   
6. 下列选项设为 `Enabled`

   ```sh
   chrome://flags/#allow-legacy-mv2-extensions
   ```