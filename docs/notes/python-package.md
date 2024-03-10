# Packaging Python projects

::: tip See: Packaging Python Projects
- https://packaging.python.org/en/latest/tutorials/packaging-projects/
:::


## Create python project

### Project structure

Suppose the package names `expkg`. The structure of this project should be like:

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

The `pyproject.toml` should be like:

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

<f>Modify the highlighted lines with the info of your own project.</f>


::: tip See: Writing your pyproject.toml
- https://packaging.python.org/en/latest/guides/writing-pyproject-toml
- https://packaging.python.org/en/latest/guides/writing-pyproject-toml/#a-full-example
:::

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

## Packaging
### Install dependencies

Install and upgrade `pip`, `build` and `twine`:

```sh
pip install --upgrade pip build twine
```

### Build package

Build the package:

```sh
python -m build
```

Successful output:

```sh
Successfully built expkg-0.0.1.tar.gz and expkg-0.0.1-py3-none-any.whl
```

This would create new folders and files <f>(highlighted)</f> like below:

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

## Upload to PyPI

### Create account

Register
on [TestPyPi <f>(Test)</f>](https://test.pypi.org/account/register)
or [PyPi <f>(Production)</f>](https://pypi.org):
- Need to verify email, and setup 2FA with Authenticator.
- Need to save the Recovery codes.
- Generate new API token.

::: warning PRC users might need proxy to make reCaptcha display correctly.
:::


### Configure token for twine

Create `.pypirc` under user home directory, and add following content:

```sh{5-7}
[testpypi]
  username = __token__
  password = pypi-...

[pypi]
  username = __token__
  password = pypi-...
```

<f>The password here is the API token generated above.</f>

### Upload package with twine

```sh{4}
# TestPyPI
twine upload --repository testpypi dist/*
# PyPI
twine upload dist/*
twine upload dist/* --skip-existing
```

## Develop and test pakcage
### Install package

Install locally (in development):

```sh{2}
# run in expkg root path
pip install -e .
```

Install from PyPI:

```sh{4}
# TestPyPI
pip install --index-url https://test.pypi.org/simple/ --no-deps expkg
# PyPI
pip install --no-deps expkg
```

### Test pakcage

```sh
python
>>> from expkg import example
>>> example.hello()
```

### One Line: rebuild and upload

```sh
python -m build && twine upload dist/* --skip-existing
```

```sh
# pip install -e .
pip install --upgrade expkg
```

## Auto publish with GitHub Actions

Create `publish_pypi.yml` in `.github/workflows`:

::: tip See: https://github.com/Hansimov/blog/blob/main/docs/notes/scripts/publish_pypi.yml
:::

<<< @/notes/scripts/publish_pypi.yml
