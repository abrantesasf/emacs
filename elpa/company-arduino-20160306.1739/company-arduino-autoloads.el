;;; company-arduino-autoloads.el --- automatically extracted autoloads (do not edit)   -*- lexical-binding: t -*-
;; Generated by the `loaddefs-generate' function.

;; This file is part of GNU Emacs.

;;; Code:

(add-to-list 'load-path (or (and load-file-name (directory-file-name (file-name-directory load-file-name))) (car load-path)))



;;; Generated autoloads from company-arduino.el

(autoload 'company-arduino-append-include-dirs "company-arduino" "\
Append Arduino's include directoreis to ORIGINAL.
If you set non-nil to ONLY-DIRS, the return value is appended
`company-arduino-includes-dirs'  Otherwise, it appends `irony-arduino-includes-options'.

(fn ORIGINAL &optional ONLY-DIRS)")
(autoload 'company-arduino-sketch-directory-p "company-arduino" "\
Check whether current directory is in sketch directory or not.")
(autoload 'company-arduino-turn-on "company-arduino" "\
Enable advice for `irony--adjust-compile-options' to add arduino's specific options.")
(autoload 'company-arduino-turn-off "company-arduino" "\
Disable advice for `irony--adjust-compile-options' of company-arduino.el.")
(register-definition-prefixes "company-arduino" '("company-arduino-" "irony-arduino-includes-options"))

;;; End of scraped data

(provide 'company-arduino-autoloads)

;; Local Variables:
;; version-control: never
;; no-byte-compile: t
;; no-update-autoloads: t
;; no-native-compile: t
;; coding: utf-8-emacs-unix
;; End:

;;; company-arduino-autoloads.el ends here