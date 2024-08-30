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

;; Ajusta a fonte padrão no Ubuntu (necessário a partir do Emacs 28):
;; Observações:
;;   1) para descobrir a fonte padrão de seu sistema, use:
;;      M-x describe-font
;;   2) para ver todas as famílias de fonte, use:
;;      M-:
;;      (message "%s" (font-family-list))
;;(add-to-list 'default-frame-alist 
;;	     '(font . "-DAMA-Ubuntu Mono-normal-normal-normal-*-31-*-*-*-m-0-iso10646-1"))
(add-to-list 'default-frame-alist 
	     '(font . "Courier Prime-30"))
;;(set-frame-font "Courier Prime" nil t)
