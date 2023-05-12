#!/bin/bash

# Parâmetros
DIR=$HOME/.emacs.d

# Faz o pull do repositório do Emacs
cd $DIR
git pull
cd $HOME

# Inicia Emacs:
/opt/emacs/bin/emacs

# Faz push para repositório do Emacs:
cd $DIR
git add .
su - -c 'update-alternatives --set pinentry $(update-alternatives --list pinentry | grep pinentry-gnome3)'
git commit -m "Atualizações"
git push
su - -c 'update-alternatives --set pinentry $(update-alternatives --list pinentry | grep pinentry-tty)'
