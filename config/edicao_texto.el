;;----------------------------------------------------------;;
;; Utilitários gerais de edição de texto
;;----------------------------------------------------------;;

;; Flash Paren Mode
(load "flash-paren")
(flash-paren-mode 1)
(setq flash-paren-delay 0.1)

;; Realça código além da coluna 80
(require 'whitespace)
(setq whitespace-line-column 80)
(setq whitespace-style '(face lines-tail))
(add-hook 'prog-mode-hook 'whitespace-mode)
(add-hook 'text-mode-hook 'whitespace-mode)

;; Wrap automático em TXT na linha 80
(add-hook 'text-mode-hook 'auto-fill-mode)
(setq-default fill-column 80)

