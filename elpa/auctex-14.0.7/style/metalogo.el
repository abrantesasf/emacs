;;; metalogo.el --- AUCTeX style for `metalogo.sty' version 0.12.  -*- lexical-binding: t; -*-

;; Copyright (C) 2013--2022 Free Software Foundation, Inc.

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

;; This file adds support for the `metalogo.sty' version 0.12.

;;; Code:

(require 'tex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "metalogo"
 (lambda ()
   (TeX-add-symbols
    ;; Logos
    '("LaTeXe")
    '("XeTeX")
    '("XeLaTeX")
    '("LuaTeX")
    '("LuaLaTeX")
    ;; Commands
    '("setlogokern"
      (TeX-arg-completing-read ("Te" "eX" "La" "aT" "Xe" "eT" "eL" "X2")
                               "Kern parameters")
      (TeX-arg-length "Dimension"))
    '("setlogodrop"
      [TeX-arg-completing-read ("TeX" "Xe" "XeTeX")
                               "Drop parameters"]
      (TeX-arg-length "Dimension"))
    '("setLaTeXa" 1)
    '("setLaTeXee" 1)
    '("seteverylogo" 1)
    '("everylogo" 1))

   ;; The main macros of this package are the logos, while fine-tuning commands
   ;; probably will be used only by expert users.
   (TeX-declare-expert-macros
    "metalogo"
    "setlogokern" "setlogodrop" "setLaTeXa" "setLaTeXee"
    "seteverylogo" "everylogo")

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '( ;; Logos
                                ("LaTeXe")
                                ("XeTeX")
                                ("XeLaTeX")
                                ("LuaTeX")
                                ("LuaLaTeX")
                                ;; Commands
                                ("setlogokern" "{{")
                                ("setlogodrop" "[{")
                                ("setLaTeXa" "{")
                                ("setLaTeXee" "{")
                                ("seteverylogo" "{")
                                ("everylogo" "{"))
                              'function)))
 TeX-dialect)

(defvar LaTeX-metalogo-package-options nil
  "Package options for the metalogo package.")

;;; metalogo.el ends here
