;;; ltugboat.el --- AUCTeX style for `ltugboat.cls' (v2.28)  -*- lexical-binding: t; -*-

;; Copyright (C) 2019--2024 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2019-05-11
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

;; This file adds support for `ltugboat.cls' (v2.28) from 2023/01/16.
;; `ltugboat.cls' is part of TeXLive.

;;; Code:

(require 'crm)
(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))
(declare-function font-latex-set-syntactic-keywords
                  "font-latex")

(TeX-add-style-hook
 "ltugboat"
 (lambda ()

   ;; Run the style hook for mflogo in order to define the macros \MF
   ;; and \MP:
   (TeX-run-style-hooks "mflogo")

   ;; Preliminaries: ltugboat.cls suppresses \part & \subparagraph
   (LaTeX-largest-level-set "section")
   (LaTeX-add-counters "section" "subsection" "subsubsection" "paragraph"
                       "figure" "table")

   ;; 6 Divisions of the paper
   (TeX-add-symbols
    '("nameref" TeX-arg-ref))

   (setq TeX-complete-list
         (append
          '(("\\\\nameref{\\([^{}\n\r\\%,]*\\)"
             1 LaTeX-completion-label-list "}"))
          TeX-complete-list))

   ;; 6.1 Abstracts
   (LaTeX-add-environments '("abstract")
                           '("longabstract"))

   ;; 6.2 Appendices: Cater for appendix environment and don't indent
   ;; the content
   (LaTeX-add-environments '("appendix"))

   (unless (string-match-p "appendix" LaTeX-document-regexp)
     (setq-local LaTeX-document-regexp
                 (concat LaTeX-document-regexp "\\|" "appendix")))

   (TeX-add-symbols
    ;; 7 Titles, addresses and so on
    '("shortTitle"  "Short title")
    '("shortAuthor" LaTeX-arg-author)
    '("address"     "Address")
    '("netaddress"  "Email address")
    '("personalURL" "Web page")
    '("ORCID"       "Digital identifier")

    ;; 7.1 Compilation articles
    '("contributor" "Contributor")
    '("makesignature" 0))

   ;; 8 Verbatim text
   (LaTeX-add-environments
    `("verbatim" LaTeX-env-args
      [TeX-arg-completing-read-multiple ("tiny"  "scriptsize" "footnotesize"
                                         "small" "normalsize" "large"
                                         "Large" "LARGE"      "huge"
                                         "Huge"  "makevmeta"  "ruled")
                                        "Command(s) (crm): \\" t
                                        ,TeX-esc
                                        ,(regexp-quote TeX-esc)
                                        ,TeX-esc]))

   ;; 10.1 Acronyms and logos
   (TeX-add-symbols
    '("acro" "Acronym")
    "AMS"
    "AmS"
    "AmSLaTeX"
    "AmSTeX"
    "ANSI"
    "API"
    "ASCII"
    "aw"
    "AW"
    "BibLaTeX"
    "BibTeX"
    "BSD"
    "CandT"
    "ConTeXt"
    "CMkIV"
    "Cplusplus"
    "CPU"
    "CSczabbr"
    "CSS"
    "CSTUG"
    "CSV"
    "CTAN"
    "DTD"
    "DTK"
    "DVD"
    "DVI"
    "DVIPDFMx"
    "DVItoVDU"
    "ECMS"
    "EPS"
    "eTeX"
    "ExTeX"
    "FAQ"
    "FTP"
    "Ghostscript"
    "GNU"
    "GUI"
    "Hawaii"
    "HTML"
    "HTTP"
    "iOS"
    "IDE"
    "IEEE"
    "ISBN"
    "ISO"
    "ISSN"
    "JPEG"
    "JTeX"
    "JoT"
    "KOMAScript"
    "LAMSTeX"
    "LuaHBTeX"
    "LuaHBLaTeX"
    "LuaLaTeX"
    "LuaTeX"
    "LyX"
    "macOS"
    "MacOSX"
    "MathML"
    "mf"
    "MFB"
    "MkIV"
    "mp"
    "NTG"
    "NTS"
    "OMEGA"
    "OCP"
    "OOXML"
    "OTF"
    "OTP"
    "mtex"
    "Pas"
    "pcMF"
    "PCteX"
    "pcTeX"
    "pdflatex"
    "pdftex"
    "PDF"
    "PGF"
    "PHP"
    "PiCTeX"
    "plain"
    "PNG"
    "POBox"
    "PS"
    "PSTricks"
    "RTF"
    "SC"
    "SGML"
    "SliTeX"
    "SQL"
    "stTeX"
    "STIX"
    "SVG"
    "TANGLE"
    "TB"
    "TIFF"
    "TP"
    "TeXhax"
    "TeXMaG"
    "TeXtures"
    "Textures"
    "TeXworks"
    "TeXXeT"
    "TFM"
    "Thanh"
    "TikZ"
    "ttn"
    "TTN"
    "TUB"
    "TUG"
    "tug"
    "UG"
    "UNIX"
    "VAX"
    "VnTeX"
    "VorTeX"
    "XML"
    "WEB"
    "WEAVE"
    "WYSIWYG"
    "XeTeX"
    "XeLaTeX"
    "XHTML"
    "XSL"
    "XSLFO"
    "XSLT"

    ;; 10.2 Other special typesetting
    "Dash"
    '("cs"  (TeX-arg-completing-read (TeX-symbol-list) "Macro"))
    '("env" (TeX-arg-completing-read (LaTeX-environment-list) "Environment"))
    '("meta"      "Text")
    '("tubbraced" "Text")
    '("nth"       "Number")

    ;; 12 Typesetting urls
    '("tburl" "Url")
    '("tbsurl" "https Url")
    '("tbhurl" "http Url")
    '("tburlfootnote" "Url")

    ;; 13 Bibliography
    '("SetBibJustification"
      (TeX-arg-completing-read ("\\raggedright" "\\sloppy") "Justification")))

   ;; Add the macros to `LaTeX-verbatim-macros-with-braces-local':
   (dolist (mac '("tburl" "tbsurl" "tbhurl" "tburlfootnote"))
     (add-to-list 'LaTeX-verbatim-macros-with-braces-local mac t))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("shortTitle"   "{")
                                ("shortAuthor"  "{")
                                ("netaddress"   "{")
                                ("personalURL"  "{")
                                ("ORCID"        "{")
                                ("contributor"  "{")
                                ("acro"         "{")
                                ("cs"           "{")
                                ("env"          "{")
                                ("meta"         "{")
                                ("tubbraced"    "{")
                                ("nth"          "{"))
                              'textual)
     (font-latex-add-keywords '(("makesignature"   "")
                                ("SetBibJustification"  "{"))
                              'function)
     (font-latex-add-keywords '(("nameref" "{")
                                ("tburl"   "")
                                ("tbsurl"  "")
                                ("tbhurl"  "")
                                ("tburlfootnote" ""))
                              'reference)
     ;; Tell font-lock about the update.
     (font-latex-set-syntactic-keywords)))
 TeX-dialect)

(defvar LaTeX-ltugboat-class-options
  '("draft" "final" "preprint"
    "extralabel" "harvardcite" "noextralabel" "nonumber" "numbersec"
    "onecolumn" "rawcite" "runningfull" "runningminimal" "runningoff"
    "a4paper" "a5paper" "b5paper" "letterpaper" "legalpaper" "executivepaper"
    "titlepage" "notitlepage" "twocolumn" "leqno" "fleqn" "openbib")
  "Package options for the ltugboat class.")

;;; ltugboat.el ends here
