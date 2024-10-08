;; captcont.el --- AUCTeX style file for captcont.sty  -*- lexical-binding: t; -*-

;; Copyright (C) 2003, 2005, 2018, 2020 Free Software Foundation, Inc.

;; Author: Reiner Steib <Reiner.Steib@gmx.de>
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

;; AUCTeX style file for captcont.sty

;;; Code:

(require 'tex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "captcont"
 (lambda ()
   (TeX-add-symbols
    '("captcont"  [ "list entry" ] "Caption")
    '("captcont*" [ "list entry" ] "Caption"))
   ;; Fontification
   (when (featurep 'font-latex)
     (font-latex-add-keywords '(("captcont" "*[{")) 'textual)))
 TeX-dialect)

(defvar LaTeX-captcont-package-options '("figbotcap" "figtopcap" "tabbotcap"
                                         "tabtopcap")
  "Package options for the captcont package.")

;;; captcont.el ends here
