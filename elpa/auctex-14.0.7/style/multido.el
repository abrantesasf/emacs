;;; multido.el --- AUCTeX style for `multido.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2007--2023 Free Software Foundation, Inc.

;; Author: Holger Sparr <holger.sparr@gmx.net>
;; Created: 21 Jun 2007
;; Based on: Jean-Philippe Georget's multido.el
;; Keywords: latex, pstricks, auctex, emacs

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

;; This file adds support for `multido.sty'.

;;; TODO:
;;
;; -- better argument support for multido
;; -- parsing for fpAdd resp. fpSub

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "multido"
 (lambda ()
   (TeX-add-symbols
    '("multido" "\\<var>=<start value>+<inc>" "Repititions" t)
    '("Multido" "\\<var>=<start value>+<inc>" "Repititions" t)
    '("mmultido" "\\<var>=<start value>+<inc>" "Repititions" t)
    '("MMultido" "\\<var>=<start value>+<inc>" "Repititions" t)
    "multidostop"
    "multidocount"
    '("fpAdd" "Summand 1" "Summand 2" "Register")
    '("fpSub" "Minuend" "Subtrahend" "Register")))
 TeX-dialect)

;;; multido.el ends here
