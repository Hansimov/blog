# 安装 Git

## 安装

```sh
sudo apt install git-all
```

## 配置全局用户名和邮箱

```sh
git config --global user.name "<username>"
git config --global user.email "<email>"
```

## 安装 GitHub CLI

```sh
conda install gh --channel conda-forge
```

::: tip See: cli/cli: GitHub's official command line tool
* https://github.com/cli/cli#installation
:::

## 登录

```sh
gh auth login
```

选项如下：

```sh
? What account do you want to log into? # GitHub.com
? What is your preferred protocol for Git operations on this host? # HTTPS
? Authenticate Git with your GitHub credentials? # Yes
? How would you like to authenticate GitHub CLI? # Login with a web browser
```

最后一步需要打开浏览器登录：
- https://github.com/login/device
- 输入8位一次性验证代码即可

::: tip See: Caching your GitHub credentials in Git - GitHub Docs
* https://docs.github.com/en/get-started/getting-started-with-git/caching-your-github-credentials-in-git?platform=linux#github-cli
:::

