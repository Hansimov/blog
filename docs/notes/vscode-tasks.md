# VSCode 自定义 tasks

## 创建 tasks.json 文件

在 Windows 下，位于：
- `C:\Users\<username>\AppData\Roaming\Code\User\tasks.json`

例如，需要创建一个自动复制当前文件相对路径和文件内容的任务，可以使用以下配置：

<<< @/notes/scripts/tasks.json

## 创建脚本

假如当前 vscode 窗口运行于远程 Linux 下，那么需要将脚本放置在远程服务器上：
- `~/scripts/copy_path_and_content.py`

<<< @/notes/scripts/copy_path_and_content.py

## 运行

按 `ctrl + shift + p`，选择 `Tasks: Run task` > `copy_path_and_content`。

或者按 `ctrl + shift + b` 快速运行上次使用的任务。