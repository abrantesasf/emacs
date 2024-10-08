;;; portuguese.el --- Setup AUCTeX for editing Portuguese text.  -*- lexical-binding: t; -*-

;; Copyright (C) 2021 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2021-05-02
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

;; Cater for some specialities of Portuguese language provided by
;; babel package, e.g. special quote and hyphen strings or `"' which
;; is an active character.

;; Thanks to Gustavo Barros <gusbrs.2016@gmail.com> for requesting
;; this feature and reviewing the code.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-quotes
                  "font-latex"
                  (quotes))

(declare-function font-latex-add-to-syntax-alist
                  "font-latex"
                  (list))

(defvar LaTeX-portuguese-mode-syntax-table
  (copy-syntax-table LaTeX-mode-syntax-table)
  "Syntax table used in LaTeX mode when using `portuguese' language.")

(modify-syntax-entry ?\" "w" LaTeX-portuguese-mode-syntax-table)

(TeX-add-style-hook
 "portuguese"
 (lambda ()
   (set-syntax-table LaTeX-portuguese-mode-syntax-table)
   (unless (eq (car TeX-quote-language) 'override)
     (setq TeX-quote-language
           `("portuguese" "\"<" "\">" ,TeX-quote-after-quote)))
   (setq LaTeX-babel-hyphen-language "portuguese")
   (TeX-add-symbols
    "ord"
    "ro"
    "orda"
    "ra")
   ;; Fontification
   (when (and (eq TeX-install-font-lock 'font-latex-setup)
              (featurep 'font-latex))
     (font-latex-add-quotes '("\"<" "\">" french))
     ;; Prevent "| from leading to color bleed.
     (font-latex-add-to-syntax-alist (list (cons ?\" "\\"))))
   (run-hooks 'TeX-language-pt-hook))
 TeX-dialect)

;;; portuguese.el ends here
