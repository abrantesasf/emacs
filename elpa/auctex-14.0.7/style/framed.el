;;; framed.el --- AUCTeX style for `framed.sty' (v0.96)  -*- lexical-binding: t; -*-

;; Copyright (C) 2016, 2020 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2016-06-26
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

;; This file adds support for `framed.sty' (v0.96) from 2011/10/22.
;; `framed.sty' is part of TeXLive.

;;; Code:

(require 'tex)
(require 'latex)

(TeX-add-style-hook
 "framed"
 (lambda ()
   ;; env's defined by framed.sty
   (LaTeX-add-environments
    '("framed")
    '("oframed")
    '("shaded")
    '("shaded*")
    '("snugshade")
    '("snugshade*")
    '("leftbar")
    '("titled-frame" "Title")))
 TeX-dialect)

(defvar LaTeX-framed-package-options nil
  "Package options for the framed package.")

;;; framed.el ends here
