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

(use-package company-clang
  :ensure t
  :config
  (setq company-clang-executable "/usr/bin/clang") ;; Verifique o caminho correto para o clang
  (add-hook 'arduino-mode-hook
            (lambda ()
              (setq-local company-backends '(company-clang company-dabbrev-code company-keywords)))))

(add-hook 'arduino-mode-hook
          (lambda ()
            (setq-local company-clang-arguments
                        '("-I/home/abrantesasf/.arduino15/libraries"
                          "-I/home/abrantesasf/.arduino15/packages/arduino/hardware/avr/1.8.6/cores/arduino"))))

;; Syntax highligth
(use-package flycheck
  :ensure t
  :hook (arduino-mode . flycheck-mode))
