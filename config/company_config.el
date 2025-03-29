;;----------------------------------------------------------;;
;; Configuração básica do company
;;----------------------------------------------------------;;

;; Não altere aqui (só se souber o que está fazendo):
(require 'company)

(company-quickhelp-mode 1)
(setq company-quickhelp-delay 0.3
      company-tooltip-align-annotations t
      company-minimum-prefix-length 2)

(global-company-mode)
(push 'slime-company slime-contribs)

(define-key company-active-map (kbd "<up>") 'company-select-previous)
(define-key company-active-map (kbd "<down>") 'company-select-next)
(define-key company-active-map (kbd "\C-n") 'company-select-next)
(define-key company-active-map (kbd "\C-p") 'company-select-previous)
(define-key company-active-map (kbd "\C-d") 'company-show-doc-buffer)
(define-key company-active-map (kbd "M-.") 'company-show-location)

(add-hook 'c-mode-hook 'company-mode)
(add-hook 'c++-mode-hook 'company-mode)
(setq company-backends '((company-clang company-files company-capf company-dabbrev-code)))

;; Includes básicos para C/C++:
(setq company-clang-arguments
  (append company-clang-arguments
    '("-I/usr/include/x86_64-linux-gnu/sysX")))

