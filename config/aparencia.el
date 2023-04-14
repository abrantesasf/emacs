;;----------------------------------------------------------;;
;; Aparência geral do Emacs
;;----------------------------------------------------------;;

;; Esconde mensagem de startup:
(setq inhibit-startup-message 't)

;; Desabilita a toolbar:
(tool-bar-mode -1)

;; Desabilita a scroolbar:
(scroll-bar-mode -1)

;; Desabilita a menu bar:
(menu-bar-mode -1)

;; Numera as colunas:
(column-number-mode 1)

;; Maximiza o Emacs ao iniciar:
(add-to-list 'initial-frame-alist '(fullscreen . maximized))

