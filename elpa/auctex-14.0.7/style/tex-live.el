;;; tex-live.el --- AUCTeX style for `tex-live.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2020--2024 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2020-03-29
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

;; This file adds support for `tex-live.sty' from 2019/08/14.
;; `tex-live.sty' is part of TeXLive.

;; Chances are high that this style is not feature complete, and
;; fontification is not ideal.  But this might be a starting point for
;; TeXLive documentation editors who use AUCTeX.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function LaTeX-add-fancyvrb-environments
                  "fancyvrb"
                  (&rest fancyvrb-environments))
(declare-function LaTeX-fancyvrb-key-val-options "fancyvrb" ())

(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(TeX-add-style-hook
 "tex-live"
 (lambda ()

   ;; Run hooks for required packages:
   (TeX-run-style-hooks "geometry"
                        "alltt"
                        "array"
                        "colortbl"
                        "comment"
                        "float"
                        "graphicx"
                        "longtable"
                        "ulem"
                        "url"
                        "xspace"
                        "relsize"
                        "fancyvrb")

   ;; Add | to a local version of `LaTeX-shortvrb-chars' before
   ;; running the style hook `shortvrb.el':
   (add-to-list (make-local-variable 'LaTeX-shortvrb-chars) ?|)
   (TeX-run-style-hooks "shortvrb")

   ;; Add support for custom environments defined with `fancyvrb.sty':
   (LaTeX-add-fancyvrb-environments
    '("verbatim" "Verbatim")
    '("sverbatim" "Verbatim")
    '("fverbatim" "Verbatim")
    '("boxedverbatim" "Verbatim"))

   (TeX-add-symbols
    '("verbatiminput" LaTeX-fancyvrb-arg-file-relative)
    '("boxedverbatiminput" LaTeX-fancyvrb-arg-file-relative)
    `("listinginput"
      (TeX-arg-completing-read
       ,(lambda () (cadr (assoc "firstnumber"
                                (LaTeX-fancyvrb-key-val-options))))
       "Value of firstnumber key")
      LaTeX-fancyvrb-arg-file-relative)

    ;; Various sorts of names:
    '("pkgname" "Package")
    '("optname" "Option")
    '("cmdname" "Command")
    '("colname" "Collection")
    '("dirname" "Directory")
    '("filename" "Directory")
    '("envname" (TeX-arg-completing-read ("TEXMFCACHE"
                                          "TEXMFCNF"
                                          "TEXMFCONFIG"
                                          "TEXMFDIST"
                                          "TEXMFHOME"
                                          "TEXMFLOCAL"
                                          "TEXMFMAIN"
                                          "TEXMFOUTPUT"
                                          "TEXMFSYSCONFIG"
                                          "TEXMFSYSVAR"
                                          "TEXMFVAR"
                                          "TEXINPUTS"
                                          "TEXFONTMAPS"
                                          "ENCFONTS"
                                          "PATH" "MANPATH" "INFOPATH" "DISPLAY")
                                         "Environment"))
    '("code" "Code")
    '("file" "File")
    '("prog" "Program")
    '("samp" "Sample")
    '("var" "Variable")
    '("ttbar" "Variable (typewriter)")

    '("Ucom" "Command (bold)")

    ;; Special names:
    '("dpi" 0)
    '("bs" 0)
    '("cs" TeX-arg-macro))

   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "dirname")
   (add-to-list 'LaTeX-verbatim-macros-with-braces-local "filename")

   (LaTeX-add-environments
    '("ttdescription" LaTeX-env-item)
    '("cmddescription" LaTeX-env-item)
    '("itemize*" LaTeX-env-item)
    '("enumerate*" LaTeX-env-item)
    '("warningbox")
    '("lrBox"))

   ;; `tex-live.sty' adds one new column specification letter P:
   (setq-local LaTeX-array-column-letters
               (concat LaTeX-array-column-letters "P"))

   ;; Custom env's where \item takes an opt. argument:
   (let ((envs '("ttdescription" "cmddescription")))
     (dolist (env envs)
       (add-to-list 'LaTeX-item-list `(,env . LaTeX-item-argument) t)))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("verbatiminput"      "{")
                                ("boxedverbatiminput" "{")
                                ("listinginput"       "{{")
                                ("pkgname"       "{")
                                ("optname"       "{")
                                ("cmdname"       "{")
                                ("colname"       "{")
                                ("dirname"       "")
                                ("filename"      "")
                                ("envname"       "{")
                                ("cs"            "{"))
                              'reference)
     (font-latex-add-keywords '(("code" "{")
                                ("file" "{")
                                ("prog" "{")
                                ("samp" "{")
                                ("ttvar" "{"))
                              'type-command)
     (font-latex-add-keywords '(("var" "{") )
                              'italic-command)
     (font-latex-add-keywords '(("Ucom" "{"))
                              'bold-command)))
 TeX-dialect)

;;; tex-live.el ends here
