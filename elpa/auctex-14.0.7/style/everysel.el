;;; everysel.el --- AUCTeX style for `everysel.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2012, 2015, 2020 Free Software Foundation, Inc.

;; Author: Mads Jensen <mje@inducks.org>
;; Created: 2012-12-25
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

;; This file adds support for `everysel.sty'.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "everysel"
 (lambda ()
   (TeX-add-symbols
    ;; adds a hook (the argument code) to be called after \\selectfont
    '("EverySelectfont" 1)
    ;; adds a hook to be called after the next \\selectfont
    '("AtNextSelectfont" 1)))
 TeX-dialect)

(defvar LaTeX-everysel-package-options nil
  "Package options for the everysel package.")

;;; everysel.el ends here
