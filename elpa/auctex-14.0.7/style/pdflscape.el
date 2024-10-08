;;; pdflscape.el --- AUCTeX style for `pdflscape.sty' (v0.11)  -*- lexical-binding: t; -*-

;; Copyright (C) 2016, 2020 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2016-07-31
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

;; This file adds support for `pdflscape.sty' (v0.11) from 2016/05/14.
;; `pdflscape.sty' is part of TeXLive.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "pdflscape"
 (lambda ()
   ;; Load lscape.el and we are done
   (TeX-run-style-hooks "lscape"))
 TeX-dialect)

(defvar LaTeX-pdflscape-package-options nil
  "Package options for the pdflscape package.")

;;; pdflscape.el ends here
