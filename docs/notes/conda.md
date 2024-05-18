# 安装 conda


## 安装

```sh
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -u
```

一路 Enter 和 yes。

## 初始化 conda

如果没有自动初始化，手动执行：

```sh
conda init
```

或者在 `.bashrc` 或 `.zshrc` 中添加：

```sh
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/asimov/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/asimov/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/asimov/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/asimov/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
```

## 测试 conda 版本

```sh
conda --version
```

## 添加国内源

一键下载覆盖：

```sh
touch ~/.condarc && wget https://raw.staticdn.net/Hansimov/blog/main/docs/notes/configs/.condarc -O ~/.condarc
```

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/configs/.condarc
:::

<<< @/notes/configs/.condarc{yml}

::: tip See: anaconda | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror
- https://mirrors.tuna.tsinghua.edu.cn/help/anaconda/
:::

## 创建 conda env

```sh
# conda create --name ai python
# conda create --name ai -c conda-forge python=3.11
conda create --name ai python=3.11
conda activate ai
conda deactivate
```

::: tip See: How to pick python 3.11 as a conda environment in vs code - Stack Overflow
* https://stackoverflow.com/questions/74959226/how-to-pick-python-3-11-as-a-conda-environment-in-vs-code
:::

## 删除 conda env

```sh
conda deactivate
conda env remove --name ai
```

## 测试 python 版本

```sh
which python
python --version
```

## 添加 alias

在 `.bash_aliases` 或 `.zshrc` 中添加：

```sh
alias cda="conda activate ai"
alias cdd="conda deactivate"
```

## 默认进入 conda env

在 `.bashrc` 或 `.zshrc` 中添加：

```sh
conda activate ai
```
