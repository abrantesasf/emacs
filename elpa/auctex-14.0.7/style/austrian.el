;;; austrian.el --- AUCTeX style for the `austrian' babel option.  -*- lexical-binding: t; -*-

;; Copyright (C) 2009, 2020 Free Software Foundation, Inc.

;; Author: Ralf Angeli <angeli@caeruleus.net>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2009-12-28
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

;; Set up AUCTeX for editing Austrian text in connection with the
;; `austrian' babel option.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "austrian"
 (lambda ()
   (TeX-run-style-hooks "german"))
 TeX-dialect)

;;; austrian.el ends here
