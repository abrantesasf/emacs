;;; ocgx.el --- AUCTeX style for `ocgx.sty' (v0.5)  -*- lexical-binding: t; -*-

;; Copyright (C) 2018--2023 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2018-08-05
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

;; This file adds support for `ocgx.sty' v0.5 from 2012/11/14.
;; `ocgx.sty' is part of TeXLive.

;;; Code:

(require 'tex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "ocgx"
 (lambda ()

   ;; Run style hook for ocg-p package:
   (TeX-run-style-hooks "ocg-p")

   ;; 1.2 Manage the visibility of OCGs
   (TeX-add-symbols
    '("switchocg" LaTeX-arg-ocgp-layer-id "Action button")

    '("showocg" LaTeX-arg-ocgp-layer-id "Action button")

    '("hideocg" LaTeX-arg-ocgp-layer-id "Action button")

    '("actionsocg"
      (LaTeX-arg-ocgp-layer-id "Toggle layer id (space separated crm)")
      (LaTeX-arg-ocgp-layer-id "Show layer id (space separated crm)")
      (LaTeX-arg-ocgp-layer-id "Hide layer id (space separated crm)")
      "Action button"))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("switchocg"  "{{")
                                ("showocg"    "{{")
                                ("hideocg"    "{{")
                                ("actionsocg" "{{{{"))
                              'function)))
 TeX-dialect)

(defvar LaTeX-ocgx-package-options nil
  "Package options for the ocgx package.")

;;; ocgx.el ends here
