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
git commit -m "Atualizações"
git push
