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

(setq company-clang-arguments
  (append company-clang-arguments
    '("-I/usr/include/gtk-3.0" "-I/usr/include/at-spi2-atk/2.0"
      "-I/usr/include/at-spi-2.0" "-I/usr/include/dbus-1.0"
      "-I/usr/lib/x86_64-linux-gnu/dbus-1.0/include"
      "-I/usr/include/x86_64-linux-gnu/sys"
      "-I/usr/include/gtk-3.0" "-I/usr/include/gio-unix-2.0"
      "-I/usr/include/cairo" "-I/usr/include/pango-1.0"
      "-I/usr/include/fribidi" "-I/usr/include/harfbuzz"
      "-I/usr/include/atk-1.0" "-I/usr/include/cairo" 
      "-I/usr/include/pixman-1" "-I/usr/include/uuid"
      "-I/usr/include/freetype2" "-I/usr/include/libpng16"
      "-I/usr/include/gdk-pixbuf-2.0" "-I/usr/include/libmount"
      "-I/usr/include/blkid" "-I/usr/include/glib-2.0"
      "-I/usr/lib/x86_64-linux-gnu/glib-2.0/include")))

