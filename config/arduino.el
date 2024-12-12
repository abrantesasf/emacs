;;----------------------------------------------------------;;
;; Configurações para o Arduino
;;----------------------------------------------------------;;

(add-to-list 'auto-mode-alist '("\\.ino\\'" . c++-mode))

(add-hook 'c++-mode-hook
  (lambda ()
    (c-set-style "k&r")
    (setq c-basic-offset 4)
    (electric-pair-mode 1)     ;; Adicionar parênteses e aspas automaticamente
    (electric-indent-mode 1))) ;; Auto-indentar

(load-file ".emacs.d/config/arduino_highlighting_code.el")

(add-to-list 'company-clang-arguments
  "-I/home/abrantesasf/.arduino15/packages/arduino/hardware/avr/1.8.6/cores/arduino/caminho/para/arduino/libraries")
(add-to-list 'company-clang-arguments
  "-I/home/abrantesasf/.arduino15/packages/arduino/hardware/avr/1.8.6/variants/standard")
(add-to-list 'company-clang-arguments
  "-I/home/abrantesasf/.arduino15/packages/arduino/hardware/avr/1.8.6/libraries")

