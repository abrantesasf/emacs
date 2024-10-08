;;; paracol.el --- AUCTeX style for `paracol.sty' (v1.35)  -*- lexical-binding: t; -*-

;; Copyright (C) 2016--2024 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2016-05-26
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

;; This file adds support for `paracol.sty' (v1.35) from 2018/12/31.
;; `paracol.sty' is part of TeXLive.

;; `paracol.sty' provides an environment (paracol) and a command
;; (\switchcolumn) which take a star as the second (!) optional
;; argument.  In order to make the input process easier for the users,
;; this style provides the environment `paracol*' and the command
;; `switchcolumn*' in the list of completion after entering C-c C-e or
;; C-c C-m (or C-c RET).

;; Further, `\switchcolumn' takes a third optional argument containing
;; text which will be inserted spanned over the columns.  This style
;; does not ask for this argument.  If you need it, just enter it by
;; hand after the completion.  This is a deliberate decision since I
;; think that over the time, the annoyance factor of hitting `RET'
;; will be larger than the number of times where this argument is
;; actually used.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(defun TeX-arg-paracol-switchcolumn* (optional)
  "Query and insert the column argument of \\switchcolum macro.
If OPTIONAL is non-nil, insert the result in square brackets."
  (let ((col (TeX-read-string
              (TeX-argument-prompt optional nil "Column"))))
    (when (and col (not (string= col "")))
      (save-excursion
        (backward-char 1)
        (TeX-argument-insert col optional)))))

(defun LaTeX-paracol--used-model (&optional xcolor)
  "Search for \\backgroundcolor and return the optional used color model.
If XCOLOR is non-nil, store the returned value in the variable
`LaTeX-xcolor-used-type-model', otherwise in the variable
`LaTeX-color-used-model'."
  (save-excursion
    (and (re-search-backward (concat (regexp-quote TeX-esc)
                                     "backgroundcolor"
                                     "\\(?:{[^}]*}\\)"
                                     "\\(?:\\[\\([^]]+\\)\\]\\)?")
                             (line-beginning-position) t)
         (set (if xcolor 'LaTeX-xcolor-used-type-model 'LaTeX-color-used-model)
              (match-string-no-properties 1))
         (not (string= "named" (match-string-no-properties 1))))))

(TeX-add-style-hook
 "paracol"
 (lambda ()

   (LaTeX-add-environments
    ;; 7.1 Environment paracol
    ;; \begin{paracol}[numleft]{num}[text] body \end{paracol}
    ;; \begin{paracol}[numleft]*{num}[text] body \end{paracol}
    '("paracol" [ "Number left" ] "Number of columns" [ "Text across columns" ] )
    '("paracol*"
      (lambda (_env)
        (let ((numleft (TeX-read-string
                        (TeX-argument-prompt  t  nil "Number left")))
              (numcol  (TeX-read-string
                        (TeX-argument-prompt nil nil "Number of columns")))
              (txt     (TeX-read-string
                        (TeX-argument-prompt  t  nil "Text across columns"))))
          (LaTeX-insert-environment
           ;; Simply feed the function with "paracol", other option is
           ;; something like:
           ;; (replace-regexp-in-string (regexp-quote "*") "" env)
           "paracol"
           (concat
            (when (and numleft (not (string= numleft "")))
              (format "[%s]" numleft))
            "*"
            (format "{%s}" numcol)
            (when (and txt (not (string= txt "")))
              (format "[%s]" txt)))))))

    ;; 7.2 Column-Switching Command and Environments
    ;; \begin{column} body \end{column}
    ;; \begin{column*}[text] body \end{column*}
    '("column")
    '("column*" [ "Text across columns" ] )

    ;; \begin{nthcolumn}{col} body \end{nthcolumn}
    ;; \begin{nthcolumn*}{col}[text] body \end{nthcolumn*}
    '("nthcolumn" "Column")
    '("nthcolumn*" "Column" [ "Text across columns" ] )

    ;; \begin{leftcolumn} body \end{leftcolumn}
    ;; \begin{leftcolumn*}[text] body \end{leftcolumn*}
    ;; \begin{rightcolumn} body \end{rightcolumn}
    ;; \begin{rightcolumn*}[text] body \end{rightcolumn*}
    '("leftcolumn")
    '("leftcolumn*" [ "Text across columns" ] )
    '("rightcolumn")
    '("rightcolumn*" [ "Text across columns" ] ))

   (TeX-add-symbols
    ;; 7.2 Column-Switching Command and Environments
    ;; \switchcolumn[col]
    ;; \switchcolumn[col]*[text]
    '("switchcolumn" [ "Column" ] )
    '("switchcolumn*" [ TeX-arg-paracol-switchcolumn* ] )
    '("thecolumn")
    '("definecolumnpreamble" "Column" t)
    '("ensurevspace" TeX-arg-length)

    ;; 7.3 Commands for Column and Gap Width
    ;; \columnratio{r0, r1, ... , rk}[r0', r1', ... , rk']
    '("columnratio" "Fraction(s)" [ "Fraction(s)" ] )

    ;; \setcolumnwidth{s0, s1, ... , sk}[s0', s1', ... , sk']
    ;; with s as width/gap
    '("setcolumnwidth" "Width/Gap" [ "Width/Gap" ] )

    ;; 7.4 Commands for Two-Sided Typesetting and Marginal Note Placement
    ;; \twosided[t1t2 ... tk]
    '("twosided" [ "Features (combination of p, c, m, b)" ])

    ;; \marginparthreshold{k}[k']
    '("marginparthreshold" "Number of columns" [ "Number of columns" ] )

    ;; 7.5 Commands for Counters
    ;; \globalcounter{ctr}
    ;; \globalcounter*
    '("globalcounter" TeX-arg-counter)
    '("globalcounter*")

    ;; \localcounter{ctr}
    '("localcounter" TeX-arg-counter)

    ;; \definethecounter{ctr}{col}{rep}
    '("definethecounter" TeX-arg-counter "Column" t)

    ;; \synccounter{ctr}
    '("synccounter" TeX-arg-counter)
    '("syncallcounters")

    ;; 7.6 Page-Wise Footnotes
    '("footnotelayout"
      (TeX-arg-completing-read ("c" "m" "p") "Layout"))

    ;; \footnote*[num]{text}
    ;; \footnotemark*[num]
    ;; \footnotetext*[num]{text}
    ;; Copied from `latex.el'
    '("footnote*"
      (TeX-arg-conditional TeX-arg-footnote-number-p ([ "Number" ]) nil)
      t)
    '("footnotetext*"
      (TeX-arg-conditional TeX-arg-footnote-number-p ([ "Number" ]) nil)
      t)
    '("footnotemark*"
      (TeX-arg-conditional TeX-arg-footnote-number-p ([ "Number" ]) nil))

    '("fncounteradjustment" 0)
    '("nofncounteradjustment" 0)

    ;; 7.7 Commands for Coloring Texts and Column-Separating Rules
    ;; \normalcolumncolor[col]
    '("normalcolumncolor" [ "Column" ] )
    '("coloredwordhyphenated" 0)
    '("nocoloredwordhyphenated" 0)

    ;; \normalcolseprulecolor[col]
    '("normalcolseprulecolor" [ "Column" ] )

    ;; 7.8 Commands for Background Painting
    ;; \nobackgroundcolor{region}
    '("nobackgroundcolor"
      (TeX-arg-completing-read ("c" "g" "s" "f" "n" "p" "t" "b" "l" "r"
                                "C" "G" "S" "F" "N" "P" "T" "B" "L" "R")
                               "Region"))
    ;; \resetbackgroundcolor
    '("resetbackgroundcolor" 0)

    ;; 7.9 Control of Contents Output
    ;; \addcontentsonly{file}{col}
    '("addcontentsonly"
      (TeX-arg-completing-read ("toc" "lof" "lot") "Content file")
      "Column")

    ;; 7.10 Page Flushing Commands
    '("flushpage" 0))

   ;; xcolor.el
   (when (member "xcolor" (TeX-style-list))
     ;; 7.7 Commands for Coloring Texts and Column-Separating Rules
     ;; \columncolor[model]{color}[col]
     ;;
     ;; This clashes if colortbl.el is loaded since it provides a
     ;; command with the same name but different arguments.  We add
     ;; the command only here but not for fontification
     (TeX-add-symbols
      '("columncolor"
        [TeX-arg-completing-read-multiple (LaTeX-xcolor-color-models)
                                          "Color model"
                                          nil nil "/" "/"]
        (TeX-arg-conditional (LaTeX-xcolor-cmd-requires-spec-p 'col)
                             (TeX-arg-xcolor)
                             ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                                       "Color name")))
        [ "Column" ] )

      ;; \colseprulecolor[model]{color}[col]
      '("colseprulecolor"
        [TeX-arg-completing-read-multiple (LaTeX-xcolor-color-models)
                                          "Color model"
                                          nil nil "/" "/"]
        (TeX-arg-conditional (LaTeX-xcolor-cmd-requires-spec-p 'col)
                             (TeX-arg-xcolor)
                             ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                                       "Color name")))
        [ "Column" ] )

      ;; 7.8 Commands for Background Painting
      ;; \backgroundcolor{region}[mode]{color}
      ;; \backgroundcolor{region(x0,y0)}[mode]{color}
      ;; \backgroundcolor{region(x0,y0)(x1,y1)}[mode]{color}
      '("backgroundcolor"
        (TeX-arg-completing-read ("c" "g" "s" "f" "n" "p" "t" "b" "l" "r"
                                  "C" "G" "S" "F" "N" "P" "T" "B" "L" "R")
                                 "Region")
        [TeX-arg-completing-read-multiple (LaTeX-xcolor-color-models)
                                          "Color model"
                                          nil nil "/" "/"]
        (TeX-arg-conditional (LaTeX-paracol--used-model t)
                             (TeX-arg-xcolor)
                             ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                                       "Color name"))))))

   ;; color.el: Always prefer xcolor.sty over color.sty
   (when (and (member "color" (TeX-style-list))
              (not (member "xcolor" TeX-active-styles)))
     (TeX-add-symbols
      '("columncolor"
        [TeX-arg-completing-read (LaTeX-color-available-models)
                                 "Color model"]
        (TeX-arg-conditional (LaTeX-color-used-model-requires-spec-p)
                             (TeX-arg-color)
                             ((TeX-arg-completing-read (LaTeX-color-available-colors)
                                                       "Color name")))
        [ "Column" ] )

      ;; \colseprulecolor[mode]{color}[col]
      '("colseprulecolor"
        [TeX-arg-completing-read (LaTeX-color-available-models)
                                 "Color model"]
        (TeX-arg-conditional (LaTeX-color-used-model-requires-spec-p)
                             (TeX-arg-color)
                             ((TeX-arg-completing-read (LaTeX-color-available-colors)
                                                       "Color name")))
        [ "Column" ] )

      ;; 7.8 Commands for Background Painting
      ;; \backgroundcolor{region}[mode]{color}
      ;; \backgroundcolor{region(x0,y0)}[mode]{color}
      ;; \backgroundcolor{region(x0,y0)(x1,y1)}[mode]{color}
      '("backgroundcolor"
        (TeX-arg-completing-read ("c" "g" "s" "f" "n" "p" "t" "b" "l" "r"
                                  "C" "G" "S" "F" "N" "P" "T" "B" "L" "R")
                                 "Region")
        [TeX-arg-completing-read (LaTeX-color-available-models)
                                 "Color model"]
        (TeX-arg-conditional (LaTeX-paracol--used-model)
                             (TeX-arg-color)
                             ((TeX-arg-completing-read (LaTeX-color-available-colors)
                                                       "Color name"))))))

   ;; \belowfootnoteskip is a length:
   (LaTeX-add-lengths "belowfootnoteskip")

   ;; \switchcolumn should get its own line:
   (LaTeX-paragraph-commands-add-locally "switchcolumn")

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("switchcolumn"                 "*["))
                              ;; FIXME: Syntax is
                              ;; \switchcolumn[num]*[text].
                              ;; font-latex.el doesn't handle the case
                              ;; where `*' comes after the first `['.
                              ;; Therefore, we use this compromise to
                              ;; get something fontified at least.
                              'textual)
     (font-latex-add-keywords '(("flushpage"                    "*["))
                              'warning)
     (font-latex-add-keywords '(("footnote"                     "*[{")
                                ("footnotemark"                 "*[")
                                ("footnotetext"                 "*[{"))
                              'reference)
     (font-latex-add-keywords '(("definecolumnpreamble"         "{{")
                                ("ensurevspace"                 "{")
                                ("columnratio"                  "{[")
                                ("setcolumnwidth"               "{[")
                                ("twosided"                     "[")
                                ("marginparthreshold"           "{[")
                                ;; FIXME: Syntax is
                                ;; \globalcounter{ctr} or
                                ;; \globalcounter* We ignore `{' since
                                ;; font-latex.el doesn't handle a
                                ;; missing bracket nicely.
                                ("globalcounter"                "*")
                                ("definethecounter"             "{{{")
                                ("synccounter"                  "{")
                                ("syncallcounters"              "")
                                ("footnotelayout"               "{")
                                ("fncounteradjustment"          "")
                                ("nofncounteradjustment"        "")
                                ("normalcolumncolor"            "[")
                                ("coloredwordhyphenated"        "")
                                ("nocoloredwordhyphenated"      "")
                                ("colseprulecolor"              "[{[")
                                ("normalcolseprulecolor"        "[")
                                ("backgroundcolor"              "{[{")
                                ("nobackgroundcolor"            "{")
                                ("resetbackgroundcolor"         "")
                                ("addcontentsonly"              "{{"))
                              'function)))
 TeX-dialect)

(defvar LaTeX-paracol-package-options nil
  "Package options for the paracol package.")

;;; paracol.el ends here
