;;----------------------------------------------------------;;
;; Configurações para uso do Git com GPG e Magit
;;----------------------------------------------------------;;
;; https://emacs.stackexchange.com/questions/64578/emacs-pinentry-not-working-on-emacs-28-0-50-and-ubuntu-20-04

(setq epa-pinentry-mode 'loopback)
(pinentry-start)
