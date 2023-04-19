;;; company-quickhelp-terminal-autoloads.el --- automatically extracted autoloads  -*- lexical-binding: t -*-
;;
;;; Code:

(add-to-list 'load-path (directory-file-name
                         (or (file-name-directory #$) (car load-path))))


;;;### (autoloads nil "company-quickhelp-terminal" "company-quickhelp-terminal.el"
;;;;;;  (0 0 0 0))
;;; Generated autoloads from company-quickhelp-terminal.el

(defvar company-quickhelp-terminal-mode nil "\
Non-nil if Company-Quickhelp-Terminal mode is enabled.
See the `company-quickhelp-terminal-mode' command
for a description of this minor mode.
Setting this variable directly does not take effect;
either customize it (see the info node `Easy Customization')
or call the function `company-quickhelp-terminal-mode'.")

(custom-autoload 'company-quickhelp-terminal-mode "company-quickhelp-terminal" nil)

(autoload 'company-quickhelp-terminal-mode "company-quickhelp-terminal" "\
Minor mode 'company-quickhelp-terminal-mode'.

This is a minor mode.  If called interactively, toggle the
`Company-Quickhelp-Terminal mode' mode.  If the prefix argument
is positive, enable the mode, and if it is zero or negative,
disable the mode.

If called from Lisp, toggle the mode if ARG is `toggle'.  Enable
the mode if ARG is nil, omitted, or is a positive number.
Disable the mode if ARG is a negative number.

To check whether the minor mode is enabled in the current buffer,
evaluate `(default-value \\='company-quickhelp-terminal-mode)'.

The mode's hook is called both when the mode is enabled and when
it is disabled.

\(fn &optional ARG)" t nil)

(register-definition-prefixes "company-quickhelp-terminal" '("company-quickhelp-terminal--"))

;;;***

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; coding: utf-8
;; End:
;;; company-quickhelp-terminal-autoloads.el ends here
