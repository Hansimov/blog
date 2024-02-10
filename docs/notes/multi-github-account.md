# Use Multiple GitHub Accounts on Same Machine

## A quick and dirty way

git clone:

```sh
git clone https://github.com/<REPO_OWNER>/<REPO>.git
```

### Method 1: Execute commands

```sh
git config --local user.name COMMITER_NAME

# NOTE: Do not forget the quotes "" around email!
git config --local user.email "COMMITER_EMAIL"

git remote set-url origin https://<COMMITTER_NAME>:<PAT>@github.com/<REPO_OWNER>/<REPO>.git

```

### Method 2: Modify config file

Just modify these settings in `.git/config`:

```sh{2,5-7}
[remote "origin"]
    url = https://<COMMITTER_NAME>:<PAT>@github.com/<REPO_OWNER>/<REPO>.git
    fetch = +refs/heads/*:refs/remotes/origin/*
...
[user]
    name = <COMMITTER_NAME>
    email = <COMMITER_EMAIL>
```

Now we can do some git operations as COMMITER_NAME ...

```sh
git add -u
git commit -m "<COMMIT_MESSAGES>"
git push
```

### References
* github-action-push-to-another-repository.sh
  * https://github.com/cpina/github-action-push-to-another-repository/blob/main/entrypoint.sh

* Create Fine-grained personal access tokens
  * https://github.com/settings/tokens?type=beta
  * Commonly used Permissions:
    * Repository permissions: (Read and write by default)
      * Actions, Commit statuses, Contents, Deployments, Discussions, Environments, Issues, Merge queues, Pages, Pull Requests, Secrets, Variables, Webhooks, Workflows
    * Account permissions:
      * None

## Guide from GitHub

### References
* How To Work With Multiple Github Accounts on your PC
  * https://gist.github.com/rahularity/86da20fe3858e6b311de068201d279e3

* SSH and GPG keys - GitHub
  * https://github.com/settings/keys

* Generating a new SSH key and adding it to the ssh-agent - GitHub Docs
  * https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
  
  * command line - ssh-add complains: Could not open a connection to your authentication agent - Unix & Linux Stack Exchange
    * https://unix.stackexchange.com/questions/48863/ssh-add-complains-could-not-open-a-connection-to-your-authentication-agent
  * ssh-add does not need `-K` anymore
    * https://gist.github.com/rahularity/86da20fe3858e6b311de068201d279e3?permalink_comment_id=4321221#gistcomment-4321221
  * Starting ssh-agent on Windows 10 fails: "unable to start ssh-agent service, error :1058" - Stack Overflow
    * https://stackoverflow.com/a/53606760/8328786

### Example
git clone:

```sh
git clone git@github.com-hansimov:Hansimov/turtle-trader.git
git clone git@gist.github.com-hansimov:a68809441cbd16290bdf98a9b5004fdb.git
```

`<repo-local-path>\.git\config`:

```sh
[core]
  ...
[remote "origin"]
	url = git@github.com-hansimov:Hansimov/turtle-trader.git
	fetch = +refs/heads/*:refs/remotes/origin/*
[branch "master"]
	remote = origin
	merge = refs/heads/master
[user]
	name = Hansimov
	email = <email-address>
```

`C:\Users\xxx\.ssh\config`:

```sh
Host github.com
    Hostname ssh.github.com
    Port 443
    ProxyCommand connect -H <proxy-server>:<port> %h %p
    IdentityFile ~/.ssh/id_rsa_work
Host github.com-hansimov
    Hostname ssh.github.com
    Port 443
    ProxyCommand connect -H <proxy-server>:<port> %h %p
    IdentityFile ~/.ssh/id_rsa_hansimov
Host gist.github.com-hansimov
    Hostname ssh.github.com
    Port 443
    ProxyCommand connect -H <proxy-server>:<port> %h %p
    IdentityFile ~/.ssh/id_rsa_hansimov
```
