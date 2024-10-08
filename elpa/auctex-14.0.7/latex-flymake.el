;;; latex-flymake.el --- Flymake integration  -*- lexical-binding: t; -*-

;; Copyright (C), 2018--2024 Free Software Foundation, Inc.

;; Author: Alex Branham <branham@utexas.edu>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2018-02-11
;; Keywords: tex

;; This file is part of AUCTeX.

;; AUCTeX is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation; either version 3, or (at your option) any
;; later version.

;; AUCTeX is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
;; FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
;; for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This file provides flymake integration for latex documents using
;; "chktex" as a backend.  You must be running Emacs 26 or newer.
;; Enable it by adding the following to your init file:

;;   (add-hook 'LaTeX-mode-hook #'flymake-mode)

;;; Code:

(require 'cl-lib)
(require 'flymake)

(defvar-local LaTeX--flymake-proc nil)

(defcustom LaTeX-flymake-chktex-options nil
  "A list of strings passed as options to the chktex backend.
You can use this to enable or disable specific warnings by setting it to
something like:

  \\='(\"-n12\" \"-w41\")

Which would disable warning 12 (\"interword spacing should perhaps be
used\") and enable 41 (\"you ought not to use primitive TeX in LaTeX
code\").

See the chktex manual for warning numbers and details about how to use
flags."
  :type '(choice (const :tag "Use chktex defaults" nil)
                 (repeat :tag "Custom chktex options" string))
  :group 'LaTeX)

(defun LaTeX-flymake (report-fn &rest _args)
  "Setup flymake integration.

REPORT-FN is flymake's callback function."
  (unless (executable-find "chktex")
    (error "Cannot find chktex"))
  (when (process-live-p LaTeX--flymake-proc)
    (kill-process LaTeX--flymake-proc))
  (let ((source (current-buffer)))
    (save-restriction
      (widen)
      (setq
       LaTeX--flymake-proc
       (make-process
        :name "LaTeX-flymake" :noquery t :connection-type 'pipe
        :buffer (generate-new-buffer " *LaTeX-flymake*")
        :command `("chktex" "--verbosity=0" "--quiet" "--inputfiles"
                   ,@LaTeX-flymake-chktex-options)
        :sentinel
        (lambda (proc _event)
          (when (eq 'exit (process-status proc))
            (unwind-protect
                (if (with-current-buffer source (eq proc LaTeX--flymake-proc))
                    (with-current-buffer (process-buffer proc)
                      (goto-char (point-min))
                      (cl-loop
                       while (search-forward-regexp
                              (rx line-start "stdin:"
                                  ;; line
                                  (group-n 1 (one-or-more num))
                                  ":"
                                  ;; column
                                  (group-n 2 (one-or-more num))
                                  ":"
                                  ;; This is information about the
                                  ;; number of the warning, which we
                                  ;; probably don't care about:
                                  (one-or-more num)
                                  ":"
                                  ;; Warning message:
                                  (group-n 3 (one-or-more not-newline)) line-end)
                              nil t)
                       for msg = (match-string 3)
                       for (beg . end) = (flymake-diag-region
                                          source
                                          (string-to-number (match-string 1))
                                          (string-to-number (match-string 2)))
                       for type = :warning
                       collect (flymake-make-diagnostic source
                                                        beg
                                                        end
                                                        type
                                                        msg)
                       into diags
                       finally (funcall report-fn diags)))
                  (flymake-log :warning "Canceling obsolete check %s"
                               proc))
              (kill-buffer (process-buffer proc)))))))
      (process-send-region LaTeX--flymake-proc (point-min) (point-max))
      (process-send-eof LaTeX--flymake-proc))))

(provide 'latex-flymake)
;;; latex-flymake.el ends here
