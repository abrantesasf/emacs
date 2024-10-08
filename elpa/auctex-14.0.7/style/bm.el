;;; bm.el --- AUCTeX style for `bm.sty'.  -*- lexical-binding: t; -*-

;; Copyright (C) 2012, 2018, 2020 Free Software Foundation, Inc.

;; Maintainer: auctex-devel@gnu.org
;; Author: Mosè Giordano <giordano.mose@libero.it>
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

;; This file adds support for `bm.sty'.

;;; Code:

(require 'tex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook "bm"
                    (lambda ()
                      (TeX-add-symbols
                       '("bm" 1)
                       '("hm" 1)
                       '("DeclareBoldMathCommand" [ "Math version" ] TeX-arg-define-macro "Math expression")
                       '("bmdefine" TeX-arg-define-macro "Math expression")
                       '("hmdefine" TeX-arg-define-macro "Math expression"))
                      ;; Fontification
                      (when (and (featurep 'font-latex)
                                 (eq TeX-install-font-lock 'font-latex-setup))
                        (font-latex-add-keywords '(("bm" "{")
                                                   ("hm" "{"))
                                                 'bold-command)
                        (font-latex-add-keywords '(("DeclareBoldMathCommand" "[|{\\{")
                                                   ("bmdefine" "|{\\{")
                                                   ("hmdefine" "|{\\{"))
                                                 'function)))
                    TeX-dialect)

(defvar LaTeX-bm-package-options nil
  "Package options for the bm package.")

;; bm.el ends here
