;;; tabulary.el --- AUCTeX style for the tabulary package.  -*- lexical-binding: t; -*-

;; Copyright (C) 2013-2024 Free Software Foundation, Inc.

;; Author: Mads Jensen <mje@inducks.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2013-07-14
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

;; This file adds support for the tabulary package.

;;; Code:

(require 'tex)
(require 'latex)

(defvar LaTeX-tabulary-package-options
  '("debugshow")
  "Package options for the tabulary package.")

(TeX-add-style-hook
 "tabulary"
 (lambda ()
   ;; Make tabulary the default tabular environment
   (setq LaTeX-default-tabular-environment "tabulary")

   ;; Append tabulary to `LaTeX-item-list' with `LaTeX-item-tabular*'
   (add-to-list 'LaTeX-item-list '("tabulary" . LaTeX-item-tabular*) t)

   ;; New symbols
   (TeX-add-symbols
    "tymax" "tymin" "tyformat")
   ;; New environments
   (LaTeX-add-environments
    ;; TODO: tabulary defines some new column types, but there is no completion
    ;; so far in `LaTeX-env-tabular*'
    '("tabulary" LaTeX-env-tabular*))

   ;; `tabulary' requires the array package
   (TeX-run-style-hooks "array")

   ;; `tabulary.sty' adds some new column specification letters.
   (setq-local LaTeX-array-column-letters
               (concat LaTeX-array-column-letters "L" "C" "R" "J")))
 TeX-dialect)

;;; tabulary.el ends here
