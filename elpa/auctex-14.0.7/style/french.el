;;; french.el --- AUCTeX style for the `french' babel option.  -*- lexical-binding: t; -*-

;; Copyright (C) 2010, 2020 Free Software Foundation, Inc.

;; Author: Ralf Angeli <angeli@caeruleus.net>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2010-03-20
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

;; Set up AUCTeX for editing French text in connection with the
;; `french' babel option.  The file basically loads the style file for
;; the `frenchb' babel option.
;;
;; Support for the FrenchPro package by Bernard Gaulle is _not_
;; included.  If the presence of FrenchPro is detected, the `frenchb'
;; support is not loaded.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "french"
 (lambda ()
   (when (and (member "babel" TeX-active-styles)
              (not (member "frenchpro" TeX-active-styles))
              (not (member "frenchle" TeX-active-styles))
              (not (member "mlp" TeX-active-styles)))
     (TeX-run-style-hooks "frenchb")))
 TeX-dialect)

;;; french.el ends here
