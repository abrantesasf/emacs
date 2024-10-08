;;; nameref.el --- AUCTeX style for `nameref.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2013--2024 Free Software Foundation, Inc.

;; Author: Mads Jensen <mje@inducks.org>
;; Maintainer: auctex-devel@gnu.org
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

;; This file adds support for `nameref.sty'

;;; Code:

(require 'tex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "nameref"
 (lambda ()
   (TeX-add-symbols
    '("nameref" TeX-arg-ref)
    '("nameref*" TeX-arg-ref)
    '("Nameref" TeX-arg-ref))

   (setq TeX-complete-list
         (append
          '(("\\\\\\(?:N\\|n\\)ameref\\*?{\\([^{}\n\r\\%,]*\\)"
             1 LaTeX-completion-label-list "}"))
          TeX-complete-list))

   ;; Fontification
   (when (and (fboundp 'font-latex-add-keywords)
              (fboundp 'font-latex-set-syntactic-keywords)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("nameref" "*{")
                                ("Nameref" "{"))
                              'reference)))
 TeX-dialect)

(defvar LaTeX-nameref-package-options nil
  "Package options for nameref.")

;; nameref.el ends here
