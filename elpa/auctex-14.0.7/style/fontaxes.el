;;; fontaxes.el --- AUCTeX style for `fontaxes.sty' version v1.0d  -*- lexical-binding: t; -*-

;; Copyright (C) 2014--2022 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2014-10-12
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

;; This file adds support for `fontaxes.sty' version v1.0d from
;; 2014/03/23.  `fontaxes.sty' is part of TeXLive.

;; Thanks to Mos� Giordano for his perceptive comments on
;; implementation of "figureversion".

;;; Code:

(require 'tex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "fontaxes"
 (lambda ()
   (TeX-add-symbols
    ;; Various font shapes:
    ;; These macros are now part of LaTeX kernel 2020-02-02
    ;; '("swshape"           -1)  ; swash shape
    ;; '("sscshape"          -1)  ; spaced small caps
    ;; '("swdefault"          0)
    ;; '("sscdefault"         0)
    ;; '("ulcdefault"         0)
    '("fontprimaryshape"   t)
    '("fontsecondaryshape" t)

    ;; Figure versions
    '("figureversion"
      (TeX-arg-completing-read-multiple ("text"         "osf"
                                         "lining"       "lf"
                                         "tabular"      "tab"
                                         "proportional" "prop")
                                        "Style, alignment"))
    '("txfigures" -1)  ; style: text figures (osf)
    '("lnfigures" -1)  ; style: lining figures
    '("tbfigures" -1)  ; alignment: tabular figures
    '("prfigures" -1)  ; alignment: proportional figures
    '("fontfigurestyle"
      (TeX-arg-completing-read ("text" "lining") "Style"))
    '("fontfigurealignment"
      (TeX-arg-completing-read ("tabular" "proportional") "Alignment"))
    '("fontbasefamily" t)

    ;; Math versions
    '("boldmath"         -1)  ; math weight
    '("unboldmath"       -1)  ;
    '("tabularmath"      -1)  ; math figure alignment
    '("proportionalmath" -1)  ;
    '("mathweight"
      (TeX-arg-completing-read ("bold" "normal") "Math weight"))
    '("mathfigurealignment"
      (TeX-arg-completing-read ("tabular" "proportional") "Math figure alignment"))

    ;; Additional commands
    ;; These macros are now part of LaTeX kernel 2020-02-02
    ;; '("textsw"              t)
    ;; '("textssc"             t)
    ;; '("textulc"             t)
    '("textfigures"         t)
    '("liningfigures"       t)
    '("tabularfigures"      t)
    '("proportionalfigures" t))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("textfigures"         "{")
                                ("liningfigures"       "{")
                                ("tabularfigures"      "{")
                                ("proportionalfigures" "{"))
                              'type-command)
     (font-latex-add-keywords '(("figureversion"       "{"))
                              'variable)))
 TeX-dialect)

(defvar LaTeX-fontaxes-package-options nil
  "Package options for the fontaxes package.")

;;; fontaxes.el ends here
