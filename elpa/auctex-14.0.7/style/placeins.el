;;; placeins.el --- AUCTeX style for `placeins.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2013, 2020 Free Software Foundation, Inc.

;; Author: Mads Jensen <mje@inducks.org>
;; Maintainer: auctex-devel@gnu.org
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

;; This file adds support for `placeins.sty'

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "placeins"
 (lambda ()
   (TeX-add-symbols
    '("FloatBarrier" 0)))
 TeX-dialect)

(defvar LaTeX-placeins-package-options 
  '("section" "above" "below" "verbose")
  "Package options for placeins.")

;; placeins.el ends here
