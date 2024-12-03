;;----------------------------------------------------------;;
;; Aparência geral do Emacs
;;----------------------------------------------------------;;

;; Lista de pacotes a serem instalados
(setq package-list
  '(dash dash-functional s ag all-the-icons async company pos-tip
    company-quickhelp f shrink-path doom-modeline doom-themes
    elisp-refs expand-region transient with-editor git-commit
    helpful loop macrostep magit memoize multiple-cursors neotree
    paredit slime slime-company smex sublime-themes yasnippet
    yasnippet-snippets yasnippet-classic-snippets ess org
    auto-package-update use-package markdown-toc markdown-soma
    markdown-mode sml-mode slime-repl-ansi-color
    company-quickhelp-terminal auctex lua-mode drag-stuff
    arduino-mode arduino-cli-mode flycheck auto-minor-mode
    company-arduino company-clang))

; fetch the list of packages available 
(unless package-archive-contents
  (package-refresh-contents))

; install the missing packages
(dolist (package package-list)
  (unless (package-installed-p package)
    (package-install package)))

; Atualiza pacotes:
(use-package auto-package-update
  :ensure t
  :config
  (setq auto-package-update-delete-old-versions t
        auto-package-update-interval 4)
  (auto-package-update-maybe))
