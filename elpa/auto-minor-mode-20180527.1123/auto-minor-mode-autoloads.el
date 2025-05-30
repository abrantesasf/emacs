;;; auto-minor-mode-autoloads.el --- automatically extracted autoloads (do not edit)   -*- lexical-binding: t -*-
;; Generated by the `loaddefs-generate' function.

;; This file is part of GNU Emacs.

;;; Code:

(add-to-list 'load-path (or (and load-file-name (directory-file-name (file-name-directory load-file-name))) (car load-path)))



;;; Generated autoloads from auto-minor-mode.el

(defvar auto-minor-mode-alist nil "\
Alist of filename patterns vs corresponding minor mode functions.

This is an equivalent of ‘auto-mode-alist’, for minor modes.

Unlike ‘auto-mode-alist’, matching is always case-folded.")
(defvar auto-minor-mode-magic-alist nil "\
Alist of buffer beginnings vs corresponding minor mode functions.

This is an equivalent of ‘magic-mode-alist’, for minor modes.

Magic minor modes are applied after ‘set-auto-mode’ enables any
major mode, so it’s possible to check for expected major modes in
match functions.

Unlike ‘magic-mode-alist’, matching is always case-folded.")
(autoload 'auto-minor-mode-set "auto-minor-mode" "\
Enable all minor modes appropriate for the current buffer.

If the optional argument KEEP-MODE-IF-SAME is non-nil, then we
don’t re-activate minor modes already enabled in the buffer.

(fn &optional KEEP-MODE-IF-SAME)")
(advice-add #'set-auto-mode :after #'auto-minor-mode-set)
(register-definition-prefixes "auto-minor-mode" '("auto-minor-mode-"))

;;; End of scraped data

(provide 'auto-minor-mode-autoloads)

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; no-native-compile: t
;; coding: utf-8-emacs-unix
;; End:

;;; auto-minor-mode-autoloads.el ends here
