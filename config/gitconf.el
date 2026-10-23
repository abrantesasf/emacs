;;-*- lexical-binding: t; -*-
;;----------------------------------------------------------;;
;; Configurações para uso do Git com GPG e Magit
;;----------------------------------------------------------;;
;; Fazer a combinação de "Emacs + GnuPG + Magit + Git" funcionar corretamente
;; foi um parto. Nada funcionava direito, trocentas mensagens de erro
;; diferentes, sites e mais sites na internet sugerindo soluções as mais
;; diversas possíveis e nenhuma dava certo. Consegui chegar na solução
;; abaixo, que está funcionando, mas só Jesus sabe porque funciona...
;;
;; Colocar em "~/.gnupg/gpg-agent.conf" e fazer o reload do agent
;; com "gpgconf --reload gpg-agent":
;;     allow-emacs-pinentry
;;     pinentry-program /usr/bin/pinentry-gnome3
;; (o modo loopback, usado abaixo, já é permitido por padrão no GnuPG 2.4;
;; o pinentry-gnome3 usa o modo texto quando não há ambiente gráfico)

(require 'epg)
(setq epg-gpg-program "gpg")
(setenv "GPG_AGENT_INFO" nil)
(setq epg-pinentry-mode 'loopback)

;; Configurações para fazer com que o Emacs NÃO SIGA os links simbólicos
;; de diretórios ao abrir arquivos, fazendo com que ele abra os arquivos
;; "dentro" do diretório que é um link simbólico, e não no diretório
;; apontado pelo link:
(setq find-file-visit-truename nil)
(setq vc-follow-symlinks nil)
