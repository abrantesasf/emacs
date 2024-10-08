;;; textpos.el --- AUCTeX style for `textpos.sty' version v1.7j  -*- lexical-binding: t; -*-

;; Copyright (C) 2015--2022 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2015-07-04
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

;; This file adds support for `textpos.sty' version v1.7j from
;; 2014/01/03.  `textpos.sty' is part of TeXLive.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function LaTeX-color-definecolor-list "color" ())
(declare-function LaTeX-xcolor-definecolor-list "xcolor" ())

(defun LaTeX-env-arg-textpos-textblock (env)
  "Query for the arguments of `textblock' environment and insert
them."
  (let* ((hsize (TeX-read-string "Width: "))
         (ho    (TeX-read-string "(Optional) X reference point: "))
         (vo    (when (not (string-equal ho ""))
                  (TeX-read-string "Y reference point: ")))
         (hpos  (TeX-read-string "X placement point: "))
         (vpos  (TeX-read-string "Y placement point: ")))
    (LaTeX-insert-environment
     env
     (concat
      (when (and hsize (not (string-equal hsize "")))
        (format "{%s}" hsize))
      (when (and ho (not (string-equal ho ""))
                 vo (not (string-equal vo "")))
        (format "[%s,%s]" ho vo))
      (when (and hpos (not (string-equal hpos ""))
                 vpos (not (string-equal vpos "")))
        (format "(%s,%s)" hpos vpos))))))

(defun LaTeX-arg-textpos-tpgrid (optional)
  "Query and insert the optional argument of `\\TPGrid'."
  (let* ((x (TeX-read-string "(Optional) X start coordinate: "))
         (y (when (not (string-equal x ""))
              (TeX-read-string "Y start coordinate: "))))
    (when (and (not (string-equal x ""))
               (not (string-equal y "")))
      (TeX-argument-insert (format "%s,%s" x y) optional))))

(TeX-add-style-hook
 "textpos"
 (lambda ()

   (TeX-run-style-hooks "everyshi")

   (LaTeX-add-environments
    ;; \begin{textblock}{<hsize>}[<ho>,<vo>](<hpos>,<vpos>) ... \end{textblock}
    '("textblock"  LaTeX-env-arg-textpos-textblock)
    '("textblock*" LaTeX-env-arg-textpos-textblock))

   (TeX-add-symbols
    '("TPGrid" [ LaTeX-arg-textpos-tpgrid ]
      "Horizontal fraction" "Vertical fraction")

    '("TPMargin"  (TeX-arg-length "Margin around textblock"))
    '("TPMargin*" (TeX-arg-length "Margin around textblock"))

    ;; We ignore the `\textblock...color' (i.e. without `u') versions
    `("textblockcolour"
      (TeX-arg-conditional (TeX-member "\\`x?color\\'" (TeX-style-list) #'string-match)
          ((TeX-arg-completing-read ,(lambda ()
                                       (or (and (fboundp 'LaTeX-xcolor-definecolor-list)
                                                (LaTeX-xcolor-definecolor-list))
                                           (and (fboundp 'LaTeX-color-definecolor-list)
                                                (LaTeX-color-definecolor-list))))
                                    "Color name"))
        ("Color name")))

    `("textblockrulecolour"
      (TeX-arg-conditional (TeX-member "\\`x?color\\'" (TeX-style-list) #'string-match)
          ((TeX-arg-completing-read ,(lambda ()
                                       (or (and (fboundp 'LaTeX-xcolor-definecolor-list)
                                                (LaTeX-xcolor-definecolor-list))
                                           (and (fboundp 'LaTeX-color-definecolor-list)
                                                (LaTeX-color-definecolor-list))))
                                    "Color name"))
        ("Color name")))

    '("TPshowboxestrue")
    '("TPshowboxesfalse")

    '("textblocklabel" t)
    '("textblockorigin" "Horizontal position" "Vertical position"))

   ;; Add the lengths defined by textpos.sty
   (LaTeX-add-lengths "TPHorizModule" "TPVertModule" "TPboxrulesize"))
 TeX-dialect)

(defvar LaTeX-textpos-package-options
  '("showboxes" "noshowtext" "absolute" "overlay" "verbose" "quiet")
  "Package options for the textpos package.")

;;; textpos.el ends here
