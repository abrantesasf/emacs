;;; ltablex.el --- AUCTeX style for `ltablex.sty' (v1.1)  -*- lexical-binding: t; -*-

;; Copyright (C) 2015--2022 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2015-03-14
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

;; This file adds support for `ltablex.sty' (v1.1) from 2014/08/13.
;; `ltablex.sty' is part of TeXLive.  `ltablex.sty' modifies the
;; tabularx environment to combine the features of the tabularx
;; package with those of the longtable package.  All we need is to
;; call those styles and add two macros.

;;; Code:

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(require 'tex)

(TeX-add-style-hook
 "ltablex"
 (lambda ()
   (TeX-run-style-hooks "tabularx" "longtable")
   (TeX-add-symbols
    '("keepXColumns" 0)
    '("convertXColumns" 0))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("keepXColumns"    "")
                                ("convertXColumns" ""))
                              'function)))
 TeX-dialect)

(defvar LaTeX-ltablex-package-options nil
  "Package options for the ltablex package.")

;;; ltablex.el ends here
