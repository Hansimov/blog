# Python 依赖管理

## pip 添加国内镜像源

一键下载覆盖到 `~/.pip/pip.conf`：

```sh
mkdir -p ~/.pip && wget https://raw.staticdn.net/Hansimov/blog/main/docs/notes/configs/pip.conf -O ~/.pip/pip.conf
```

或者运行：
```sh
mkdir -p ~/.pip && nano ~/.pip/pip.conf
```

写入下面内容：

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/pip.conf
:::

<<< @/notes/configs/pip.conf{ini}

查看 pip 配置：

```sh
pip config list
```

::: tip PyPI - USTC Mirror Help
* https://mirrors.ustc.edu.cn/help/pypi.html

pip 使用国内镜像源 | 菜鸟教程
* https://www.runoob.com/w3cnote/pip-cn-mirror.html

pypi | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror
* https://mirrors.tuna.tsinghua.edu.cn/help/pypi
:::

## 临时使用源安装

```sh
# 中科大源
pip install -i https://mirrors.ustc.edu.cn/pypi/simple -U pip

# 官方源
pip install -i https://pypi.org/simple -U pip
```

## 安装 pipreqs

```sh
python -m pip install pipreqs
```

## 生成 requirements.txt

不指定版本：

```sh
pipreqs . --force --mode no-pin --encoding=utf-8
```

兼容版本：

```sh
pipreqs . --force --mode compat --encoding=utf-8
```