;;----------------------------------------------------------;;
;; Configurações para uso do Git com GPG e Magit
;;----------------------------------------------------------;;
;; https://emacs.stackexchange.com/questions/64579/emacs-pinentry-not-working-on-emacs-28-0-50-and-ubuntu-20-04
;; https://emacs.stackexchange.com/questions/32881/enabling-minibuffer-pinentry-with-emacs-25-and-gnupg-2-1-on-ubuntu-xenial/68304#68304

;; In ~/.gnupg/gpg-agent.conf:
;; allow-emacs-pinentry
(require 'epg)
(setq epg-gpg-program "gpg")
(setenv "GPG_AGENT_INFO" nil)
(setq epa-pinentry-mode 'loopback)
(pinentry-start)
