;;; fontenc.el --- AUCTeX style for `fontenc.sty' (v1.99g)  -*- lexical-binding: t; -*-

;; Copyright (C) 2015--2023  Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2015-09-12
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

;; This file adds support for `fontenc.sty' (v1.99g) from 2005/09/27.
;; `fontenc.sty' is a standard LaTeX package and part of TeXLive.

;;; Code:

(defvar LaTeX-fontenc-package-options
  '(;; 128+ glyph encodings (text)
    "OT1" "OT2" "OT3" "OT4" "OT6"
    ;; 256 glyph encodings (text)
    "T1" "T2A" "T2B" "T2C" "T3" "T4" "T5"
    ;; 256 glyph encodings (text extended)
    "X2"
    ;; Other encodings
    "LY1" "LV1" "LGR")
  "Package options for the fontenc package.")

;;; fontenc.el ends here
