;;; markdown-soma-autoloads.el --- automatically extracted autoloads  -*- lexical-binding: t -*-
;;
;;; Code:

(add-to-list 'load-path (directory-file-name
                         (or (file-name-directory #$) (car load-path))))


;;;### (autoloads nil "markdown-soma" "markdown-soma.el" (0 0 0 0))
;;; Generated autoloads from markdown-soma.el

(autoload 'markdown-soma-toggle-source-view "markdown-soma" "\
Toggle source view or FORCE on/off.

FORCE will expect a prefix positive integer to mean on or
negative prefix to mean off.

This will trigger markdown-soma-restart in an active session.

\(fn FORCE)" t nil)

(autoload 'markdown-soma-restart "markdown-soma" "\
Restart a running soma session." t nil)

(register-definition-prefixes "markdown-soma" '("markdown-soma-"))

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; markdown-soma-autoloads.el ends here
