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
;; com "gpgconf --kill gpg-agent":
;;     allow-emacs-pinentry
;;     allow-loopback-pinentry
;;     pinentry-program /usr/bin/pinentry-gnome3

(require 'epg)
(setq epg-gpg-program "gpg")
(setenv "GPG_AGENT_INFO" nil)
(setq epa-pinentry-mode 'loopback)
