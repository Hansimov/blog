# Python 依赖管理

## 修改 pip 镜像源

创建 `~/.pip/pip.conf`：

```sh
mkdir -p ~/.pip
touch ~/.pip/pip.conf
```

并添加：

```sh
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple
[install]
trusted-host = https://pypi.tuna.tsinghua.edu.cn
```

查看 pip 配置：

```sh
pip config list
```

::: tip See: pip 使用国内镜像源 | 菜鸟教程
* https://www.runoob.com/w3cnote/pip-cn-mirror.html

See: pypi | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror
* https://mirrors.tuna.tsinghua.edu.cn/help/pypi
:::

## 安装 pipreqs

```sh
python -m pip install pipreqs
```

## 生成 requirements.txt

```sh
pipreqs . --force --mode no-pin --encoding=utf-8
```