;;; newpxmath.el --- AUCTeX style for `newpxmath.sty' (v1.232)  -*- lexical-binding: t; -*-

;; Copyright (C) 2015, 2020 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2015-05-02
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

;; This file adds support for `newpxmath.sty' (v1.232) from 2015/04/07.
;; `newpxmath.sty' is part of TeXLive.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "newpxmath"
 (lambda ()

   ;; Run style hook for amsmath
   (TeX-run-style-hooks "amsmath")

   ;; New symbols
   (TeX-add-symbols
    '("overgroup"      t)
    '("undergroup"     t)
    '("overgroupra"    t)
    '("overgroupla"    t)
    '("undergroupra"   t)
    '("undergroupla"   t)
    '("widering"       t)
    '("widearc"        t)
    '("wideOarc"       t)
    '("uppartial"      0)
    '("upvarkappa"     0)
    '("varmathbb"      "Character")
    '("vmathbb"        "Character")
    '("vvmathbb"       "Character")))
 TeX-dialect)

(defvar LaTeX-newpxmath-package-options
  '("varg"
    "cmintegrals"
    "uprightGreek"
    "slantedGreek"
    "cmbraces"
    "bigdelims"
    "varbb"
    "vvarbb"
    "nosymbolsc"
    "amssymbols"
    "noamssymbols"
    "frenchmath")
  "Package options for the newpxmath package.")

;;; newpxmath.el ends here
