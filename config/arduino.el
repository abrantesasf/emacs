;;----------------------------------------------------------;;
;; Configurações para o Arduino
;;----------------------------------------------------------;;
;;
;; É necessário ter a IDE do Arduino (arduino.cc) instalada;
;; É necessário ter o arduino-cli (github.com/arduino/arduino-cli) instalado;

;; Major mode
(use-package arduino-mode
  :ensure t
  :mode ("\\.ino\\'" . arduino-mode))

;; Autocomplete
(add-hook 'arduino-mode-hook
  (lambda ()
    (setq-local company-backends '((company-dabbrev-code company-keywords)))))

;; Syntax highligth
(use-package flycheck
  :ensure t
  :hook (arduino-mode . flycheck-mode))
