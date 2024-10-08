;;; titletoc.el --- AUCTeX style for `titletoc.sty' (v1.6)  -*- lexical-binding: t; -*-

;; Copyright (C) 2016--2024 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2015-09-19
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

;; This file adds support for `titletoc.sty' (v1.6) from
;; 2011/12/15.  `titletoc.sty' is part of TeXLive.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(defvar LaTeX-titletoc-section-command-list
  '("part"
    "chapter"
    "section"
    "subsection"
    "subsubsection"
    "paragraph"
    "subparagraph"
    "figure"
    "table")
  "List of sectioning commands available in \"titletoc.sty\".
Other environments producing a \"Table of ENVIRONMENT\" (figure,
table) are also available in this variable.")

(defun LaTeX-titletoc-section-command-list ()
  "Return a list of appropriate sectioning commands.
Commands are collected from the variable
`LaTeX-titletoc-section-command-list' and selected based on the
return value of the function `LaTeX-largest-level'."
  (if (< (LaTeX-largest-level) 2)
      (symbol-value 'LaTeX-titletoc-section-command-list)
    (remove "chapter" LaTeX-titletoc-section-command-list)))

;; Setup for \contentsuse:
(TeX-auto-add-type "titletoc-contentsuse" "LaTeX")

(defvar LaTeX-titletoc-contentsuse-regexp
  '("\\\\contentsuse{\\([^}]+\\)}"
    1 LaTeX-auto-titletoc-contentsuse)
  "Matches the argument of \\contentsuse from titletoc package.")

(defun LaTeX-titletoc-auto-prepare ()
  "Clear `LaTeX-auto-titletoc-contentsuse' before parsing."
  (setq LaTeX-auto-titletoc-contentsuse nil))

(defun LaTeX-titletoc-auto-cleanup ()
  "Process parsed arguments of \"\\contentsuse\".
Parsed elements are added to the variable
`LaTeX-titletoc-section-command-list'."
  (when (LaTeX-titletoc-contentsuse-list)
    (make-local-variable 'LaTeX-titletoc-section-command-list)
    (dolist (content (mapcar #'car (LaTeX-titletoc-contentsuse-list)))
      (add-to-list 'LaTeX-titletoc-section-command-list content))))

(add-hook 'TeX-auto-prepare-hook #'LaTeX-titletoc-auto-prepare t)
(add-hook 'TeX-auto-cleanup-hook #'LaTeX-titletoc-auto-cleanup t)
(add-hook 'TeX-update-style-hook #'TeX-auto-parse t)

(TeX-add-style-hook
 "titletoc"
 (lambda ()

   ;; Add titletoc to the parser
   (TeX-auto-add-regexp LaTeX-titletoc-contentsuse-regexp)

   (TeX-add-symbols
    ;; Basic macros
    ;; \dottedcontents{<section>}[<left>]{<above-code>}
    ;;                {<label width>}{<leader width>}
    '("dottedcontents"
      (TeX-arg-completing-read (LaTeX-titletoc-section-command-list)
                               "Sectioning command")
      [TeX-arg-length "Left margin"]
      3)

    ;; \titlecontents{<section>}[<left>]{<above-code>}
    ;;               {<numbered-entry-format>}{<numberless-entry-format>}
    ;;               {<filler-page-format>}[<below-code>]
    '("titlecontents"
      (TeX-arg-completing-read (LaTeX-titletoc-section-command-list)
                               "Sectioning command")
      [TeX-arg-length "Left margin"]
      (TeX-arg-conditional (y-or-n-p "With optional below code argument? ")
          (4 [nil])
        (4)))

    ;; \titlecontents*{<section>}[<left>]{<above-code>}
    ;;                {<numbered-entry-format>}{<numberless-entry-format>}
    ;;                {<filler-page-format>}[<separator>]
    '("titlecontents*"
      (TeX-arg-completing-read (LaTeX-titletoc-section-command-list)
                               "Sectioning command")
      [TeX-arg-length "Left margin"]
      (TeX-arg-conditional (y-or-n-p "With optional separator argument? ")
          (4 [nil])
        (4)))

    ;; \contentsmargin[<correction>]{<right>}
    '("contentsmargin" [ "Correction" ] "Right margin")

    '("thecontentslabel" 0)

    '("thecontentspage" 0)

    '("contentslabel" [ "Format" ] (TeX-arg-length "Space"))

    '("contentspage" [ "Format" ])

    '("contentspush" t)

    ;; Check if newfloat.el is loaded and any new environment is
    ;; defined with it.  titletoc.sty can also be used to customize
    ;; new environments defined with newfloat.sty.  As a prerequisite,
    ;; the environments must be introduced to titletoc.sty with
    ;; \contentuse{ENV} and then can be used as argument to \titlecontents.
    '("contentsuse"
      (lambda (optional)
        (let ((name (if (and (member "newfloat" (TeX-active-styles))
                             (LaTeX-newfloat-DeclareFloatingEnvironment-list))
                        (completing-read
                         (TeX-argument-prompt optional nil "Name of contents")
                         (mapcar #'car
                                 (LaTeX-newfloat-DeclareFloatingEnvironment-list)))
                      (TeX-read-string
                       (TeX-argument-prompt optional nil "Name of contents")))))
          (make-local-variable 'LaTeX-titletoc-section-command-list)
          (add-to-list 'LaTeX-titletoc-section-command-list name)
          (TeX-argument-insert name optional)))
      "File extension")

    ;; 6.3. Partial TOC's
    '("startcontents" [ "Name" ])

    '("stopcontents" [ "Name" ])

    '("resumecontents" [ "Name" ])

    '("printcontents" [ "Name" ] "Prefix" "Start level" t)

    ;; 6.4. Partial lists
    '("startlist" [ "Name" ] "List")

    '("stoplist" [ "Name" ] "List")

    '("resumelist" [ "Name" ] "List")

    '("printlist" [ "Name" ] "Prefix" t) )

   ;; Fontification: We only add macros which are used at top level;
   ;; most of macros definded above are intended to be used in
   ;; arguments of \dottedcontents or \titlecontents
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("dottedcontents"  "{[{{{")
                                ("titlecontents"   "*{[{{{[[[")
                                ("contentsmargin"  "[{")
                                ("contentsuse"     "{{"))
                              'function)) )
 TeX-dialect)

(defvar LaTeX-titletoc-package-options
  '("leftlabels" "rightlabels" "dotinlabels")
  "Package options for the titletoc package.")

;;; titletoc.el ends here
