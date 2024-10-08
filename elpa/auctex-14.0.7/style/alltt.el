;;; alltt.el --- AUCTeX style for `alltt.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2004, 2005, 2014, 2016, 2018, 2020 Free Software Foundation, Inc.

;; Author: Ralf Angeli <angeli@iwi.uni-sb.de>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2004-04-30
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

;; This file adds support for `alltt.sty'.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-set-syntactic-keywords
                  "font-latex")

(TeX-add-style-hook
 "alltt"
 (lambda ()
   (LaTeX-add-environments "alltt")
   (add-to-list (make-local-variable 'LaTeX-indent-environment-list)
                '("alltt" current-indentation) t)
   (add-to-list 'LaTeX-verbatim-environments-local "alltt")
   ;; Fontification
   (when (and (fboundp 'font-latex-set-syntactic-keywords)
              (eq TeX-install-font-lock 'font-latex-setup))
     ;; Tell font-lock about the update.
     (font-latex-set-syntactic-keywords)))
 TeX-dialect)

(defvar LaTeX-alltt-package-options nil
  "Package options for the alltt package.")

;;; alltt.el ends here
