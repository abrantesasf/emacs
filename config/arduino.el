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

;; Minor mode
(use-package arduino-cli-mode
  :ensure t
  ;; :hook arduino-mode
  ;; :mode "\\.ino\\'"
  :custom
  (arduino-cli-warnings 'all)
  (arduino-cli-verify t))

(add-to-list 'auto-minor-mode-alist '("\\.ino\\'" . arduino-cli-mode))

;; Autocomplete
(use-package company
  :ensure t
  :hook (arduino-mode . company-mode))

(add-hook 'arduino-mode-hook 'company-mode)

(add-hook 'arduino-mode-hook
  (lambda ()
    (setq-local company-backends '((company-dabbrev-code company-keywords company-files)))))

;; Syntax highligth
(use-package flycheck
  :ensure t
  :hook (arduino-mode . flycheck-mode))
