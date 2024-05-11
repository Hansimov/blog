# backup .zshrc
cp ~/.zshrc ~/.zshrc.bak

# get customized .zshrc
wget https://raw.githubusercontent.com/Hansimov/blog/main/docs/notes/configs/.zshrc -O ~/.zshrc

# install zsh-autosuggestions
mkdir -p ~/.zsh/zsh-autosuggestions
wget https://raw.githubusercontent.com/zsh-users/zsh-autosuggestions/master/zsh-autosuggestions.zsh -O ~/.zsh/zsh-autosuggestions.zsh

# install zsh-autocomplete
cd ~/.zsh
git clone --depth 1 -- https://github.com/marlonrichert/zsh-autocomplete.git && cd ~
cd ~
touch ~/.zshenv
echo "skip_global_compinit=1" > ~/.zshenv

# enable changes
zsh