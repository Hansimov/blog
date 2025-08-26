# 允许新版 Chrome 使用旧版插件

::: tip Chrome插件不能用，这些扩展程序不再受支持，因此已停用，25年7月12日更新！ - 知乎
https://zhuanlan.zhihu.com/p/1927399384947065539
:::

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