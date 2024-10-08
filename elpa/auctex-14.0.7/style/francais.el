;;; francais.el --- AUCTeX style for the `francais' babel option.  -*- lexical-binding: t; -*-

;; Copyright (C) 2005, 2020 Free Software Foundation, Inc.

;; Author: Ralf Angeli <angeli@iwi.uni-sb.de>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2005-10-28
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

;; Set up AUCTeX for editing French text.  In particular for commands
;; provided by the `francais' option of the `babel' LaTeX package.  As
;; this is equivalent to the `frenchb' option, this file only loads
;; `frenchb.el'.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "francais"
 (lambda ()
   (TeX-run-style-hooks "frenchb"))
 TeX-dialect)

;;; francais.el ends here
