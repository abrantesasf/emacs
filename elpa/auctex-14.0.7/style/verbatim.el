;;; verbatim.el --- Style hook for the verbatim package.  -*- lexical-binding: t; -*-

;; Copyright (C) 2001--2024 Free Software Foundation, Inc.

;; Author: Masayuki Ataka <masayuki.ataka@gmail.com>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2001/05/01

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

;;  M-x TeX-auto-generate verbatim.sty makes garbages.

;;; Code

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-set-syntactic-keywords
                  "font-latex")
(declare-function font-latex-add-keywords
                  "font-latex")

(TeX-add-style-hook
 "verbatim"
 (lambda ()
   (LaTeX-add-environments
    "comment")
   (TeX-add-symbols
    '("verbatiminput" TeX-arg-file)
    '("verbatiminput*" TeX-arg-file))

   ;; Fontification:
   ;; Code taken from `comment.el'
   (when (and (boundp 'font-latex-syntactic-keywords-extra)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("verbatiminput" "*{"))
                              'reference)
     ;; For syntactic fontification.
     (add-to-list 'font-latex-syntactic-keywords-extra
                  '("^[ \t]*\\\\begin *{comment}.*\\(\n\\)"
                    (1 "!" t)))
     (add-to-list 'font-latex-syntactic-keywords-extra
                  '("^[ \t]*\\(\\\\\\)end *{comment}"
                    (1 "!" t)))
     ;; Tell font-lock about the update.
     (font-latex-set-syntactic-keywords)))
 TeX-dialect)

(defvar LaTeX-verbatim-package-options nil
  "Package options for the verbatim package.")

;;; verbatim.el ends here.
