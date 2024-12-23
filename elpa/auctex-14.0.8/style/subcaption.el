;;; subcaption.el --- AUCTeX style for `subcaption.sty' (v1.6)  -*- lexical-binding: t; -*-

;; Copyright (C) 2015--2024 Free Software Foundation, Inc.

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

;; This file adds support for `subcaption.sty' (v1.6) from 2023-08-13.
;; `subcaption.sty' is part of TeXLive.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))
(defvar LaTeX-caption-key-val-options)

(defvar LaTeX-subcaption-key-val-options
  '(("subrefformat" ("default" "empty" "simple" "brace" "parens")))
  "Key=value options for subcaption package.
This key takes the same values as \"labelformat\" from caption
package.")

(defun LaTeX-arg-subcaption-subcaption (optional &optional star)
  "Query for the arguments of \"\\subcaption\" incl. a label and insert them.
If OPTIONAL is non-nil, indicate it while reading the caption.
If STAR is non-nil, then do not query for a \\label and a short
caption, insert only a caption."
  (let* (;; \subcaption needs an environment, "minipage" will be
         ;; popular.  If so, check next higher environment to find out
         ;; where we are
         (currenv (if (string= (LaTeX-current-environment) "minipage")
                      (LaTeX-current-environment 2)
                    (LaTeX-current-environment)))
         (caption (TeX-read-string
                   (TeX-argument-prompt optional nil "Sub-caption")))
         (short-caption
          (when (and (not star)
                     (>= (length caption) LaTeX-short-caption-prompt-length))
            (TeX-read-string
             (TeX-argument-prompt t nil "Short caption")))))
    (indent-according-to-mode)
    (when (and short-caption (not (string= short-caption "")))
      (insert LaTeX-optop short-caption LaTeX-optcl))
    (insert TeX-grop caption TeX-grcl)
    ;; Fill the \subcaption paragraph before inserting the \label:
    (when auto-fill-function (LaTeX-fill-paragraph))
    (when (and (not star)
               (save-excursion (LaTeX-label currenv 'environment)))
      ;; Move \label into next line if we have one:
      (LaTeX-newline)
      (indent-according-to-mode)
      (end-of-line))))

(defun LaTeX-arg-subcaption-subcaptionbox (optional &optional star)
  "Query for the arguments of \"\\subcaptionbox\" incl. a label and insert them.
If OPTIONAL is non-nil, indicate it while reading the caption.
If STAR is non-nil, then do not query for a \\label and a short
caption, insert only a caption."
  (let* ((currenv (LaTeX-current-environment))
         (caption (TeX-read-string
                   (TeX-argument-prompt optional nil "Sub-caption")))
         (short-caption
          (when (and (not star)
                     (>= (length caption) LaTeX-short-caption-prompt-length))
            (TeX-read-string
             (TeX-argument-prompt t nil "Short Sub-caption")))))
    (indent-according-to-mode)
    (when (and short-caption (not (string= short-caption "")))
      (insert LaTeX-optop short-caption LaTeX-optcl))
    (insert TeX-grop caption)
    (unless star (LaTeX-label currenv 'environment))
    (insert TeX-grcl))
  (let* ((TeX-arg-opening-brace "[")
         (TeX-arg-closing-brace "]")
         (width (completing-read (TeX-argument-prompt t nil "Width")
                                 (mapcar (lambda (elt) (concat TeX-esc (car elt)))
                                         (LaTeX-length-list))))
         (inpos (if (and width (not (string-equal width "")))
                    (completing-read (TeX-argument-prompt t nil "Inner position")
                                     '("c" "l" "r" "s"))
                  "")))
    (TeX-argument-insert width t)
    (TeX-argument-insert inpos t))
  ;; Fill the paragraph before inserting {}.  We use this function
  ;; since we add \subcaption to `paragraph-start' in the style hook
  ;; below.
  (when auto-fill-function (LaTeX-fill-paragraph)))

(defun LaTeX-env-subcaption-subcaptionblock (environment)
  "Create new LaTeX subcaptionblock ENVIRONMENT.
This function is a copy of `LaTeX-env-minipage' with the option list for
outer-pos adjusted."
  (let* ((pos (and LaTeX-default-position
                   (completing-read
                    (TeX-argument-prompt t nil "Position")
                    '("t" "b" "c" "T" "B"))))
         (height (when (and pos (not (string= pos "")))
                   (completing-read (TeX-argument-prompt t nil "Height")
                                    (mapcar (lambda (elt)
                                              (concat TeX-esc (car elt)))
                                            (LaTeX-length-list)))))
         (inner-pos (when (and height (not (string= height "")))
                      (completing-read
                       (TeX-argument-prompt t nil "Inner position")
                       '("t" "b" "c" "s"))))
         (width (TeX-read-string
                 (TeX-argument-prompt nil nil (format "Width (default %s)"
                                                      LaTeX-default-width))
                 nil nil LaTeX-default-width)))
    (setq LaTeX-default-position pos)
    (setq LaTeX-default-width width)
    (LaTeX-insert-environment environment
                              (concat
                               (unless (zerop (length pos))
                                 (concat LaTeX-optop pos LaTeX-optcl))
                               (unless (zerop (length height))
                                 (concat LaTeX-optop height LaTeX-optcl))
                               (unless (zerop (length inner-pos))
                                 (concat LaTeX-optop inner-pos LaTeX-optcl))
                               (concat TeX-grop width TeX-grcl)))))

(TeX-add-style-hook
 "subcaption"
 (lambda ()
   ;; Run style hook for caption.el
   (TeX-run-style-hooks "caption")

   (TeX-add-symbols
    ;; Basic commands
    '("subcaptionsetup"
      [TeX-arg-completing-read LaTeX-caption-supported-float-types
                               "Float type"]
      (TeX-arg-key-val (LaTeX-caption-key-val-options)))
    '("subcaption"     (LaTeX-arg-subcaption-subcaption))
    '("subcaption*"    (LaTeX-arg-subcaption-subcaption     t)  )
    '("subcaptionbox"  (LaTeX-arg-subcaption-subcaptionbox) t)
    '("subcaptionbox*" (LaTeX-arg-subcaption-subcaptionbox  t) t)
    '("subref"         TeX-arg-ref)
    ;; \subref* is only available with hyperref.sty loaded, we don't
    ;; check if hyperref.el is loaded and make it available directly.
    '("subref*"        TeX-arg-ref)
    '("phantomcaption"    0)
    '("phantomsubcaption" 0)
    '("subfloat" [ "List entry" ] [ "Sub-caption" ] t))

   ;; The next 2 macros are part of the kernel of caption.sty, but we
   ;; load them within subcaption.el.
   (TeX-add-symbols
    `("DeclareCaptionSubType"
      [TeX-arg-completing-read ("arabic" "roman" "Roman"
                                "alph" "Alph" "fnsymbol")
                               "Numbering scheme"]
      (TeX-arg-completing-read
       ,(lambda ()
          (append
           (when (and (fboundp 'LaTeX-newfloat-DeclareFloatingEnvironment-list)
                      (LaTeX-newfloat-DeclareFloatingEnvironment-list))
             (mapcar #'car (LaTeX-newfloat-DeclareFloatingEnvironment-list)))
           '("figure" "table")))
       "Type"))

    `("DeclareCaptionSubType*"
      [TeX-arg-completing-read ("arabic" "roman" "Roman"
                                "alph" "Alph" "fnsymbol")
                               "Numbering scheme"]
      (TeX-arg-completing-read
       ,(lambda ()
          (append
           (when (and (fboundp 'LaTeX-newfloat-DeclareFloatingEnvironment-list)
                      (LaTeX-newfloat-DeclareFloatingEnvironment-list))
             (mapcar #'car (LaTeX-newfloat-DeclareFloatingEnvironment-list)))
           '("figure" "table")))
       "Type")))

   ;; \subcaption(box|setup)? and \subfloat macros should get their
   ;; own lines
   (LaTeX-paragraph-commands-add-locally
    '("subcaption" "subcaptionbox" "subcaptionsetup" "subfloat"))

   (LaTeX-add-environments
    ;; 4 The subcaptionblock environment
    '("subcaptionblock" LaTeX-env-subcaption-subcaptionblock)
    '("subfigure" LaTeX-env-minipage)
    '("subtable"  LaTeX-env-minipage)

    ;; 5 The subcaptiongroup environment
    "subcaptiongroup" "subcaptiongroup*")

   ;; Append env's to `LaTeX-label-alist':
   (add-to-list 'LaTeX-label-alist '("subfigure" . LaTeX-figure-label) t)
   (add-to-list 'LaTeX-label-alist '("subtable" . LaTeX-table-label) t)

   ;; Introduce env's to RefTeX if loaded
   (when (fboundp 'reftex-add-label-environments)
     (reftex-add-label-environments
      `(("subfigure" ?f ,LaTeX-figure-label "~\\ref{%s}" caption)
        ("subtable"  ?t ,LaTeX-table-label  "~\\ref{%s}" caption))))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("subcaption"            "*[{")
                                ("subcaptionbox"         "*[{[[")
                                ("phantomcaption"        "")
                                ("phantomsubcaption"     "")
                                ("subfloat"              "[["))
                              'textual)
     (font-latex-add-keywords '(("subref"                "*{"))
                              'reference)
     (font-latex-add-keywords '(("DeclareCaptionSubType" "*[{")
                                ("subcaptionsetup"       "[{"))
                              'function)) )
 TeX-dialect)

(defvar LaTeX-subcaption-package-options-list
  (progn
    (TeX-load-style "caption")
    (append LaTeX-subcaption-key-val-options
            LaTeX-caption-key-val-options))
  "Package options for the subcaption package.")

(defun LaTeX-subcaption-package-options ()
  "Prompt for package options for the subcaption package."
  (TeX-read-key-val t LaTeX-subcaption-package-options-list))

;;; subcaption.el ends here
