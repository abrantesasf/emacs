;;; gloss-italian.el --- Italian support for polyglossia package.  -*- lexical-binding: t; -*-

;; Copyright (C) 2015, 2018, 2020, 2022 Free Software Foundation, Inc.

;; Maintainer: auctex-devel@gnu.org
;; Author: Mosè Giordano <mose@gnu.org>
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

;; This is based on italian.el style file, adapted to polyglossia package.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-quotes
                  "font-latex"
                  (quotes))

(declare-function LaTeX-polyglossia-lang-option-member
                  "polyglossia" (language option))

(defvar TeX-language-it-hook nil
  "Hook run for Italian texts.")

(TeX-add-style-hook
 "gloss-italian"
 (lambda ()
   (TeX-add-symbols
    '("textitalian" [TeX-arg-key-val LaTeX-polyglossia-italian-options-list] t))
   (LaTeX-add-environments
    '("italian"
      LaTeX-env-args [TeX-arg-key-val LaTeX-polyglossia-italian-options-list]))

   (when (or (LaTeX-polyglossia-lang-option-member "italian" "babelshorthands=true")
             (LaTeX-polyglossia-lang-option-member "italian" "babelshorthands"))
     (unless (eq (car TeX-quote-language) 'override)
       (setq TeX-quote-language
             `("italian" "\"<" "\">" ,TeX-quote-after-quote)))

     ;; Fontification of quotation marks.
     (when (fboundp 'font-latex-add-quotes)
       (font-latex-add-quotes '("\"<" "\">" french))))
   (run-hooks 'TeX-language-it-hook))
 TeX-dialect)

(defvar LaTeX-polyglossia-italian-options-list
  '(("babelshorthands" ("true" "false")))
  "Italian language options for the polyglossia package.")

;;; gloss-italian.el ends here
