;;; makeidx.el --- AUCTeX support for makeidx.sty  -*- lexical-binding: t; -*-

;; Copyright (C) 1999, 2020, 2022 Free Software Foundation, Inc.

;; Author: Carsten Dominik <dominik@strw.leidenuniv.nl>
;; Maintainer: auctex-devel@gnu.org

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

;;; Code:

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(require 'tex)

(TeX-add-style-hook
 "makeidx"
 (lambda ()
   (TeX-add-symbols
    "printindex")

   ;; Parsing the default index macro is defined in latex.el
   ;; The same is true form completion in the index macro

   ;; Completion for the |see macro
   (setq TeX-complete-list
         (append
          '(("|see{\\([^{}\n\r]*\\)" 1 LaTeX-index-entry-list))
          TeX-complete-list))

   ;; RefTeX support
   (and (fboundp 'reftex-add-index-macros)
        (reftex-add-index-macros '(default)))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("printindex" ""))
                              'function)))
 TeX-dialect)

(defvar LaTeX-makeidx-package-options nil
  "Package options for the makeidx package.")

;;; makeidx.el ends here
