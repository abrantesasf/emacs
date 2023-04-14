;;----------------------------------------------------------;;
;; Fullscreen ao estilo do Firefox
;;----------------------------------------------------------;;
;; Retirado de: http://www.emacswiki.org/emacs/FullScreen

(defun toggle-fullscreen (&optional f)
  (interactive)
  (let ((current-value (frame-parameter nil 'fullscreen)))
    (set-frame-parameter
     nil 'fullscreen
     (if (equal 'fullboth current-value)
         (if (boundp 'old-fullscreen) old-fullscreen nil)
       (progn (setq old-fullscreen current-value)
              'fullboth)))))

(global-set-key [f11] 'toggle-fullscreen)

;; Para iniciar em fullscreen, descomente a linha abaixo:
;(toggle-fullscreen)

