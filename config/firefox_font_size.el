;;-*- lexical-binding: t; -*-
;;----------------------------------------------------------;;
;; Ajuste do tamanho da fonte ao estilo Firefox e, além
;; disso, aumenta o tamanho padrão da fonte da tela
;;----------------------------------------------------------;;
;; Retirado de: https://groups.csail.mit.edu/mac/users/gjs/6.945/index.html

(defvar rlm-default-font-size 220)

(defvar rlm-font-size
  rlm-default-font-size)

(defun change-font-size (num)
  (setq rlm-font-size (+ rlm-font-size num))
  (message (number-to-string rlm-font-size))
  (set-face-attribute 'default nil
                      :height rlm-font-size))

(defun font-increase ()
  (interactive)
  (change-font-size 10))

(defun font-decrease ()
  (interactive)
  (change-font-size -10))

(defun font-restore ()
  (interactive)
  (setq rlm-font-size rlm-default-font-size)
  (change-font-size 0))

(global-set-key (kbd "C-+") 'font-increase)
(global-set-key (kbd "C--") 'font-decrease)
(global-set-key (kbd "C-=") 'font-restore)

;; A fonte padrão é definida em font.el.
