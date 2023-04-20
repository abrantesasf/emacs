;;----------------------------------------------------------;;
;; Utilitário para verificação ortográfica
;;----------------------------------------------------------;;
;; Obs.: é necessário que o Aspell ou o Hunspell estejam
;; instalados no Linux. O Hunspell permite o uso simultâneo
;; de mais de uma linguagem e é ele que vou usar:
;;    apt install hunspell hunspell-pt-br hunspell-en-gb hunspell-en-us
;; Para mais informações:
;;    https://200ok.ch/posts/2020-08-22_setting_up_spell_checking_with_multiple_dictionaries.html
;;    https://www.tenderisthebyte.com/blog/2019/06/09/spell-checking-emacs/


;; Configuração do Hunspell para usar dicionários Português e Inglês:
(with-eval-after-load "ispell"
  (setenv "LANG" "en_US.UTF-8")
  (setq ispell-program-name "hunspell")
  (setq ispell-dictionary "pt_BR,en_GB,en_US")
  (ispell-set-spellchecker-params)
  (ispell-hunspell-add-multi-dic "pt_BR,en_GB,en_US")
  (setq ispell-personal-dictionary "~/.emacs.d/hunspell_personal"))

;; Ativa o Flyspell para o modo de texto e derivados:
(dolist (hook '(text-mode-hook))
  (add-hook hook (lambda () (flyspell-mode 1))))

