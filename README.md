# EMACS

Minhas configurações padronizadas para o Emacs. Crie um link simbólico para
o repositório, para o dot_emacs e para o emacs.sh:

     cd ~
     ln -s <repositorio> ~/.emacs.d
     ln -s ~/.emacs.d/dot_emacs ~/.emacs
     ln -s ~/.emacs.d/emacs.sh ~/bin/emacs.sh

Para ter o atalho na área de trabalho (ele chama o emacs.sh):

     cp ~/.emacs.d/emacs.desktop ~/Desktop/

O emacs.sh faz commits assinados com GPG ao fechar o Emacs. Para que a senha
da chave seja pedida mesmo quando o Emacs é aberto pelo atalho (sem
terminal), crie o arquivo "~/.gnupg/gpg-agent.conf" com:

     allow-emacs-pinentry
     pinentry-program /usr/bin/pinentry-gnome3

e recarregue o agent com:

     gpgconf --reload gpg-agent

Para compilar o Emacs (atualmente o 31.1, em /opt/emacs), veja o arquivo
comando_configure.txt.

Sim, é antigo; sim, existem jeitos melhores; sim, é quase "infantil". Mas
é o jeito que eu gosto.

Obrigado!
