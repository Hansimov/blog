# 安装 conda


## 安装

```sh
wget https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda/Miniconda3-latest-Linux-x86_64.sh -O Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -u -p "$HOME/miniconda3"
```

国内网络下优先使用镜像地址，避免从 `repo.anaconda.com` 慢速下载。交互安装也可以不加 `-b -p "$HOME/miniconda3"`，一路 Enter 和 yes。

## 初始化 conda

如果没有自动初始化，手动执行：

```sh
conda init
```

或者在 `.bashrc` 或 `.zshrc` 中添加：

```sh
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="$HOME/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
```

重启终端：`bash` 或 `zsh`。

## 测试 conda 版本

```sh
conda --version
```

## 添加国内源

::: tip Anaconda - USTC Mirror Help
- https://mirrors.ustc.edu.cn/help/anaconda.html

anaconda | 镜像站使用帮助 | 清华大学开源软件镜像站 | Tsinghua Open Source Mirror
- https://mirrors.tuna.tsinghua.edu.cn/help/anaconda/
:::

```sh
# conda config --show-sources
nano ~/miniconda3/.condarc
```

修改为如下内容：

```yaml
channels:
  - conda-forge
  - bioconda
  - nodefaults
custom_channels:
  conda-forge: https://mirrors.ustc.edu.cn/anaconda/cloud
  bioconda: https://mirrors.ustc.edu.cn/anaconda/cloud
show_channel_urls: true
```

清除缓存:

```sh
conda clean -i
```

测试：

```sh
# 详见：创建 conda env
# conda create -n myenv numpy -c conda-forge
```

## 创建 conda env

::: tip See: How to pick python 3.11 as a conda environment in vs code - Stack Overflow
* https://stackoverflow.com/questions/74959226/how-to-pick-python-3-11-as-a-conda-environment-in-vs-code
:::


```sh
# conda create --name ai python
# conda create --name ai python=3.11 --override-channels -c https://mirrors.ustc.edu.cn/anaconda/cloud/conda-forge
conda create --name ai python=3.13 --override-channels -c https://mirrors.ustc.edu.cn/anaconda/cloud/conda-forge
conda activate ai
conda deactivate
```

`--override-channels` 可以避免新版 conda 在默认 Anaconda channels 上触发非交互 ToS 确认；自动化脚本中建议显式使用 conda-forge 镜像。

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

在 `~/.bash_aliases` 或 `~/.zshrc` 中添加：

```sh
alias cda="conda activate ai"
alias cdd="conda deactivate"
```

## 默认进入 conda env

在 `~/.bashrc` 或 `~/.zshrc` 中添加：

```sh
conda activate ai
```
