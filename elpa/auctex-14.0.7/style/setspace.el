;;; setspace.el --- AUCTeX style for `setspace.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2011, 2018, 2020 Free Software Foundation, Inc.

;; Author: Mads Jensen <mje@inducks.org>
;; Created: 2011-04-16
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

;; This file adds support for `setspace.sty'.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "setspace"
 (lambda ()
   (TeX-add-symbols
    '("setstretch" "Stretch")
    '("setdisplayskipstretch" "Stretch")
    '("SetSinglespace" "Stretch")
    '("onehalfspacing" 0)
    '("doublespacing" 0)
    '("singlespacing" 0))

   (LaTeX-add-environments 
    '("spacing" "Stretch")
    "singlespace"
    "singlespace*"
    "onehalfspace"
    "doublespace")

   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("singlespacing" "")
                                ("doublespacing" "")
                                ("onehalfspacing" ""))
                              'function)))
 TeX-dialect)

(defvar LaTeX-setspace-package-options 
  '("doublespacing" "onehalfspacing" "singlespacing" "nodisplayskipstretch")
  "Package options for the setspace package.")

;;; setspace.el ends here
