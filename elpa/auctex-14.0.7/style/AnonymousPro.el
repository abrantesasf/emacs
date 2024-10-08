;;; AnonymousPro.el --- AUCTeX style for `AnonymousPro.sty' (v2.2)  -*- lexical-binding: t; -*-

;; Copyright (C) 2014, 2019, 2020 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2014-10-30
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

;; This file adds support for `AnonymousPro.sty' (v2.2) from
;; 2019/07/07.  `AnonymousPro.sty' is part of TeXLive.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "AnonymousPro"
 (lambda ()

   ;; Run style hook for textcomp
   (TeX-run-style-hooks "textcomp")

   ;; New symbols
   (TeX-add-symbols
    "ANPapplelogo"
    "ANPappleopen"
    "ANPapproxequal"
    "ANPback"
    "ANPblackdiamond"
    "ANPcheckmark"
    "ANPcopy"
    "ANPellipsis"
    "ANPendtab"
    "ANPerasetotheright"
    "ANPgreaterequal"
    "ANPHbar"
    "ANPhbar"
    "ANPinfinity"
    "ANPinsert"
    "ANPintegral"
    "ANPlessequal"
    "ANPlozenge"
    "ANPnotequal"
    "ANPoptionkey"
    "ANPpartialdiff"
    "ANPPi"
    "ANPpi"
    "ANPproduct"
    "ANPshift"
    "ANPshiftlock"
    "ANPSigma"
    "ANPsigma"
    "ANPsigmaone"
    "ANPsummation"
    "ANPtab"
    "ANPReturnSign"
    "ANPShoulderedOpenBox"
    "ANPUpArrowHead"
    "ANPInsertSign"
    "ANPUpArrowHeadBars"
    "ANPHelm"
    "ANPOpenBox"
    "ANPDelta"
    "ANPverticaltab"
    "ANPNumeroSign"))
 TeX-dialect)

(defvar LaTeX-AnonymousPro-package-options
  '("ttdefault" "scale" "scaled")
  "Package options for the AnonymousPro package.")

;;; AnonymousPro.el ends here
