#!/bin/bash

# Parâmetros
DIR="$HOME/.emacs.d"

# Mostra uma mensagem no terminal e, se houver ambiente gráfico, também
# como notificação (o script pode ser iniciado pelo emacs.desktop, sem
# terminal):
avisa() {
    echo "emacs.sh: $1" >&2
    command -v notify-send > /dev/null && notify-send "Emacs" "$1"
}

# Faz o pull do repositório do Emacs:
PULL_OK=1
if ! git -C "$DIR" pull; then
    PULL_OK=0
    avisa "Falha no git pull. O Emacs vai abrir com a configuração local e, ao fechar, as alterações não serão enviadas (push)."
fi

# Inicia Emacs:
cd "$HOME"
/opt/emacs/bin/emacs

# Não faz commit se houver conflito pendente (por exemplo, de um pull que
# falhou), para não gravar marcadores de conflito no repositório:
if [ -n "$(git -C "$DIR" ls-files --unmerged)" ]; then
    avisa "Há conflitos no repositório $DIR. Resolva manualmente; nada foi gravado."
    exit 1
fi

# Faz commit das alterações (se houver):
git -C "$DIR" add .
if git -C "$DIR" diff --cached --quiet; then
    exit 0
fi
if ! git -C "$DIR" commit -m "Atualizações"; then
    avisa "Falha no git commit (verifique a assinatura GPG)."
    exit 1
fi

# Faz push para repositório do Emacs (só se o pull funcionou):
if [ "$PULL_OK" -eq 1 ]; then
    git -C "$DIR" push || avisa "Falha no git push. O commit ficou só no repositório local."
else
    avisa "Commit feito só no repositório local (o pull tinha falhado). Faça pull e push manualmente."
fi
