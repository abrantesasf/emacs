;;-*- lexical-binding: t; -*-
;;----------------------------------------------------------;;
;; Fullscreen ao estilo do Firefox
;;----------------------------------------------------------;;
;; Retirado de: http://www.emacswiki.org/emacs/FullScreen

;; Guarda o estado anterior ao fullscreen:
(defvar old-fullscreen nil)

(defun toggle-fullscreen ()
  (interactive)
  (let ((current-value (frame-parameter nil 'fullscreen)))
    (set-frame-parameter
     nil 'fullscreen
     (if (equal 'fullboth current-value)
         old-fullscreen
       (progn (setq old-fullscreen current-value)
              'fullboth)))))

(global-set-key [f11] 'toggle-fullscreen)

;; Para iniciar em fullscreen, descomente a linha abaixo:
;(toggle-fullscreen)

