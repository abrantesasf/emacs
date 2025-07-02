;;----------------------------------------------------------;;
;; Ajusta a fonta padrão para o Emacs
;;----------------------------------------------------------;;

;; Ajusta a fonte padrão no Ubuntu (necessário a partir do Emacs 28):
;; Observações:
;;   1) para descobrir a fonte padrão de seu sistema, use:
;;      M-x describe-font
;;   2) para ver todas as famílias de fonte, use:
;;      M-:
;;      (message "%s" (font-family-list))
;;(add-to-list 'default-frame-alist 
;;	     '(font . "-DAMA-Ubuntu Mono-normal-normal-normal-*-31-*-*-*-m-0-iso10646-1"))
;;(add-to-list 'default-frame-alist 
;;	     '(font . "Courier Prime-22"))
;;(set-frame-font "Courier Prime" nil t)
(add-to-list 'default-frame-alist 
	     '(font . "Berkeley Mono SemiBold-22"))
