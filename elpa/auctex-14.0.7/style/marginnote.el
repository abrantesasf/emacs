;;; marginnote.el --- AUCTeX style for `marginnote.sty' (v1.4)  -*- lexical-binding: t; -*-

;; Copyright (C) 2018--2021 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2018-07-07
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

;; This file adds support for `marginnote.sty' (v1.4) from 2018/07/01.
;; `marginnote.sty' is part of TeXLive.

;;; Code:

(require 'tex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "marginnote"
 (lambda ()

   (TeX-add-symbols
    '("marginnote" [ "Left margin text" ] "Text"
      [ TeX-arg-length "Vertical offset" ] )

    "marginnotetextwidth"
    "marginnotevadjust"
    "raggedleftmarginnote"
    "raggedrightmarginnote"
    "marginfont")

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("marginnote"  "[{["))
                              'reference)))
 TeX-dialect)

(defvar LaTeX-marginnote-package-options
  '("fulladjust" "heightadjust" "depthadjust" "noadjust"
    "parboxrestore" "noparboxrestore")
  "Package options for the marginnote package.")

;;; marginnote.el ends here
