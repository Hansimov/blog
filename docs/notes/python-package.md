# Python 打包发布

::: tip See: Packaging Python Projects
- https://packaging.python.org/en/latest/tutorials/packaging-projects/
:::

## 创建 Python 项目

### 项目结构

假如包名为 `expkg`，则项目结构形如：

```sh
working_dir/
├── CHANGELOG.md
├── LICENSE
├── README.md
├── pyproject.toml
├── src/
│   └── expkg/
│       ├── __init__.py
│       └── example.py
└── tests/
```

### pyproject.toml

`pyproject.toml` 形如:

```toml{2,3,5,7,15,18-20}
[project]
name = "expkg"
version = "0.0.1"
authors = [
    { name="<author>" },
]
description = "This is an example package."
readme = "README.md"
requires-python = ">=3.6"
classifiers = [
    "Programming Language :: Python :: 3",
    "License :: OSI Approved :: MIT License",
    "Operating System :: OS Independent",
]
dependencies = [ ]

[project.urls]
Homepage = "https://github.com/<author>/expkg"
Issues = "https://github.com/<author>/expkg/issues"
Changelog = "https://github.com/<author>/expkg/blob/main/CHANGELOG.md"
```

<f>将高亮行修改为实际项目信息，将 <code>expkg</code> 替换为实际包名。</f>


::: tip See: Writing your pyproject.toml
- https://packaging.python.org/en/latest/guides/writing-pyproject-toml
- https://packaging.python.org/en/latest/guides/writing-pyproject-toml/#a-full-example
:::

### LICENSE

以 MIT 为例，`LICENSE` 文件形如：

```txt{1}
Copyright (c) 2024 <author>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

<f>将年份和作者改为实际信息。</f>

## 打包项目
### 安装依赖

安装和升级 `pip`、`build`、`twine`：

```sh
pip install --upgrade pip build twine
```

### 构建包

```sh
python -m build
```

若成功，输出形如：

```sh
Successfully built expkg-0.0.1.tar.gz and expkg-0.0.1-py3-none-any.whl
```

会新建下面高亮的文件夹和文件：

```sh{2-4,6}
working_dir/
├── dist/
│   ├── expkg-0.0.1-py3-none-any.whl
│   └── expkg-0.0.1.tar.gz
├── src/
│   ├── expkg.egg-info/
│   ├── expkg/
│   └── ...
└── ...
```

## 上传 PyPI

### 创建账户

注册[TestPyPi <f>(Test)</f>](https://test.pypi.org/account/register)
或 [PyPi <f>(Production)</f>](https://pypi.org)：
- 需要验证邮箱，并配置 2FA 认证
- 需保存 Recovery codes
- 生成新的 API token

::: warning 国内用户可能需要代理以正常显示 reCaptcha。
:::


### 配置 twine 的 token

在用户 home 目录下创建 `.pypirc`，添加内容如下：

```sh{5-7}
[testpypi]
  username = __token__
  password = pypi-...

[pypi]
  username = __token__
  password = pypi-...
```

<f>这里的 password 就是上面生成的 API token。</f>

### 使用 twine 上传包

```sh{4}
# TestPyPI
twine upload --repository testpypi dist/*
# PyPI
twine upload dist/*
twine upload dist/* --skip-existing
```

## 开发和测试包
### 安装包

本地安装（适用于开发过程中）：

```sh{2}
# run in expkg root path
pip install -e .
```

从 PyPI 安装：

```sh{4}
# TestPyPI
pip install --index-url https://test.pypi.org/simple/ --no-deps expkg
# PyPI
pip install --no-deps expkg
# pip install --no-deps --upgrade -i https://pypi.python.org/simple/ expkg
```

### 测试包

```sh
python
>>> from expkg import example
>>> example.hello()
```

### 一键构建和上传

```sh
python -m build && twine upload dist/* --skip-existing
```

```sh
# pip install -e .
pip install --upgrade expkg --no-cache-dir
```

## 利用 GitHub Actions 自动发布

在 `.github/workflows` 中创建 `publish_pypi.yml`，内容如下：

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/publish_pypi.yml
:::

<<< @/notes/scripts/publish_pypi.yml
