# Packaging Python projects

::: tip See: Packaging Python Projects
- https://packaging.python.org/en/latest/tutorials/packaging-projects/
:::


## Create python project

### Project structure

Suppose the package names `exp_pkg`. The structure of this project should be like:

```sh
working_dir/
├── LICENSE
├── pyproject.toml
├── README.md
├── src/
│   └── exp_pkg/
│       ├── __init__.py
│       └── example.py
└── tests/
```

### pyproject.toml

The `pyproject.toml` should be like:

```toml{2,3,5,7,17,18}
[project]
name = "exp-pkg"
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

[project.urls]
Homepage = "https://github.com/<author>/exp-pkg"
Issues = "https://github.com/<author>/exp-pkg/issues"
```

<f>Modify the highlighted lines with the info of your own project.</f>

### LICENSE

Suppose the license is MIT, the `LICENSE` file might look like below.

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

<f>Modify the year and author with yours.</f>

## Build package

Install and upgrade `pip` and `build`:

```sh
pip install --upgrade pip
pip install --upgrade build
```

Then build the package:

```sh
python -m build
```

This would create new folders and files <f>(highlighted)</f> like below:

```sh{2-4,6}
working_dir/
├── dist/
│   ├── exp_pkg-0.0.1-py3-none-any.whl
│   └── exp_pkg-0.0.1.tar.gz
├── src/
│   ├── exp_pkg.egg-info/
│   ├── exp_pkg/
│   └── ...
└── ...
```

## Upload to TestPyPI

### Create account

::: tip Goto: https://test.pypi.org/account/register/
:::

::: warning PRC users might need proxy to make reCaptcha display correctly.
:::

Following the steps to finish register.

Notes:
- Need to verify email, and setup 2FA with Authenticator.
- Need to save the Recovery codes.
- Generate new API token.

### Configure token for twine

Create `.pypirc` under user home directory, and add following content:

```sh
[testpypi]
  username = __token__
  password = pypi-...
```

<f>The password here is the API token generated above.</f>


### Upload package with twine

```sh
pip install --upgrade twine
```

```sh
twine upload --repository testpypi dist/*
```

## Install and test the package

Install from TestPyPI:

```sh
pip install --index-url https://test.pypi.org/simple/ --no-deps exp-pkg
```

Test the package:

```sh
python
>>> from exp_pkg import example
>>> example.hello()
```
