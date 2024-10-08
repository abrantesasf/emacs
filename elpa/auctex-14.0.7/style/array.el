;;; array.el --- AUCTeX style for `array.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2013-2024  Free Software Foundation, Inc.

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

;; This file adds support for `array.sty'

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-auto-add-type "array-newcolumntype" "LaTeX")

(defvar LaTeX-array-newcolumntype-regexp
  '("\\\\newcolumntype{\\([^}]+\\)}"
    1 LaTeX-auto-array-newcolumntype)
  "Matches the argument of `\\newcolumntype' from `array'
package.")

(defun LaTeX-array-auto-prepare ()
  "Clear `LaTeX-auto-array-newcolumntype' before parsing."
  (setq LaTeX-auto-array-newcolumntype nil))

(defun LaTeX-array-auto-cleanup ()
  "Move parsed column specification from
`LaTeX-auto-array-newcolumntype' to `LaTeX-array-column-letters'."
  (when (LaTeX-array-newcolumntype-list)
    (LaTeX-array-update-column-letters)))

(defun LaTeX-array-update-column-letters ()
  "Update and uniquify the local value of `LaTeX-array-column-letters'."
  (setq-local LaTeX-array-column-letters
              (let* ((newtypes (mapconcat #'car (LaTeX-array-newcolumntype-list) ""))
                     (alltypes (concat LaTeX-array-column-letters newtypes)))
                (seq-concatenate 'string (seq-uniq alltypes #'=)))))

(add-hook 'TeX-auto-prepare-hook #'LaTeX-array-auto-prepare t)
(add-hook 'TeX-auto-cleanup-hook #'LaTeX-array-auto-cleanup t)
(add-hook 'TeX-update-style-hook #'TeX-auto-parse t)

(TeX-add-style-hook
 "array"
 (lambda ()

   (TeX-auto-add-regexp LaTeX-array-newcolumntype-regexp)

   (TeX-add-symbols
    `("newcolumntype"
      ,(lambda (optional)
         (let ((col (TeX-read-string
                     (TeX-argument-prompt optional nil "Column type"))))
           (LaTeX-add-array-newcolumntypes col)
           (LaTeX-array-update-column-letters)
           (TeX-argument-insert col optional)))
      [ "Number of arguments" ] t)
    '("showcols" 0)
    '("firsthline" 0)
    '("lasthline" 0))

   ;; `array.sty' adds a couple of new lengths.  They're added here, rather than
   ;; in the `TeX-add-symbols' block.
   (LaTeX-add-lengths "extratabsurround" "extrarowheight")

   ;; `array.sty' adds some new column specification letters.
   (setq-local LaTeX-array-column-letters
               (concat LaTeX-array-column-letters "m" "b" "w" "W"))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("newcolumntype" "{[{"))
                              'function)))
 TeX-dialect)

(defvar LaTeX-array-package-options nil
  "Package options for array.")

;; array.el ends here
