;;; mdframed.el --- AUCTeX style for `mdframed.sty' (v1.9b)  -*- lexical-binding: t; -*-

;; Copyright (C) 2016--2022 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2016-06-26
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

;; This file adds support for `mdframed.sty' (v1.9b) from 2013/07/01.
;; `mdframed.sty' is part of TeXLive.

;; This style offers only a set of mandatory options for completion
;; while loading the package
;; (cf. `LaTeX-mdframed-package-options-list').  All other options are
;; offered for completion as part of `\mdfsetup'.  Please use this
;; command to set options of the package.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(declare-function LaTeX-color-definecolor-list "color" ())
(declare-function LaTeX-xcolor-definecolor-list "xcolor" ())

(defvar LaTeX-mdframed-key-val-options
  '(;; 6.2. Restoring the settings
    ("style" ("defaultoptions"))
    ("default")
    ;; 6.3. Options with lengths
    ("defaultunit" ("pt" "pc" "in" "bp" "cm" "mm" "dd" "cc" "sp" "ex" "em"))
    ("skipabove")
    ("skipbelow")
    ("leftmargin")
    ("rightmargin")
    ("innerleftmargin")
    ("innerrightmargin")
    ("innertopmargin")
    ("innerbottommargin")
    ("linewidth")
    ("innerlinewidth")
    ("middlelinewidth")
    ("outerlinewidth")
    ("roundcorner")
    ;; 6.4. Colored Options
    ("linecolor")
    ("innerlinecolor")
    ("middlelinecolor")
    ("outerlinecolor")
    ("backgroundcolor")
    ("fontcolor")
    ("font")
    ;; 6.5. Shadows
    ("shadowsize")
    ("shadowcolor")
    ;; 6.6. Hidden Lines
    ("topline" ("true" "false"))
    ("rightline" ("true" "false"))
    ("leftline" ("true" "false"))
    ("bottomline" ("true" "false"))
    ("hidealllines" ("true" "false"))
    ;; 6.7. Working in twoside-mode
    ("outermargin")
    ("innermargin")
    ("usetwoside" ("true" "false"))
    ;; 6.8. Footnotes
    ("footnotedistance")
    ("footnoteinside" ("true" "false"))
    ;; 6.9. Page breaks
    ("nobreak" ("true" "false"))
    ("everyline" ("true" "false"))
    ("splittopskip")
    ("splitbottomskip")
    ;; 6.10. Frametitle
    ("frametitle")
    ("frametitlefont")
    ("frametitlealignment" ("\\raggedleft" "\\raggedright" "\\centering"))
    ("frametitlerule" ("true" "false"))
    ("frametitlerulewidth")
    ("frametitleaboveskip")
    ("frametitlebelowskip")
    ("frametitlebackgroundcolor")
    ("repeatframetitle" ("true" "false"))
    ;; 6.11. Title commands inside the environment
    ("subtitleaboveline" ("true" "false"))
    ("subtitlebelowline" ("true" "false"))
    ("subtitlefont")
    ("subtitlebackgroundcolor")
    ("subtitleabovelinecolor")
    ("subtitlebelowlinecolor")
    ("subtitleabovelinewidth")
    ("subtitlebelowlinewidth")
    ("subtitleaboveskip")
    ("subtitlebelowskip")
    ("subtitleinneraboveskip")
    ("subtitleinnerbelowskip")
    ;; 6.12. General options
    ("ntheorem" ("true" "false"))
    ("needspace")
    ("ignorelastdescenders" ("true" "false"))
    ("userdefinedwidth" ("\\linewidth" "\\columnwidth"))
    ("align" ("left" "right" "center"))
    ;; 6.13. TikZ options
    ("tikzsetting")
    ("apptotikzsetting")
    ;; 6.14. PSTricks options
    ("pstrickssetting")
    ("pstricksappsetting")
    ;; 7. Hooks and Bools
    ("settings")
    ("extra")
    ("singleextra")
    ("firstextra")
    ("middleextra")
    ("secondextra")
    ("mdfsingleframe" ("true" "false"))
    ("mdffirstframe" ("true" "false"))
    ("mdfmiddleframe" ("true" "false"))
    ("mdflastframe" ("true" "false"))
    ("beforesingleframe")
    ("aftersingleframe")
    ("beforebreak")
    ("afterbreak")
    ("beforelastframe")
    ("afterlastframe")
    ("startcode")
    ("startinnercode")
    ("endinnercode")
    ("endcode")
    ;; 8. Theorems
    ("theoremseparator")
    ("theoremtitlefont")
    ("theoremspace"))
  "Key=value options for mdframed macros and environments.")

;; Setup for \newmdenv

(TeX-auto-add-type "mdframed-newmdenv" "LaTeX")

(defvar LaTeX-mdframed-newmdenv-regexp
  `(,(concat
      "\\\\newmdenv"
      "[ \t\n\r%]*"
      "\\(?:"
      (LaTeX-extract-key-value-label 'none)
      "\\)?"
      "[ \t\n\r%]*"
      "{\\([^}]+\\)}")
    1 LaTeX-auto-mdframed-newmdenv)
  "Matches the argument of \\newmdenv from mdframed package.")

;; Setup for \mdfdefinestyle

(TeX-auto-add-type "mdframed-mdfdefinestyle" "LaTeX")

(defvar LaTeX-mdframed-mdfdefinestyle-regexp
  '("\\\\mdfdefinestyle[ \t\n\r%]*{\\([^}]+\\)}"
    1 LaTeX-auto-mdframed-mdfdefinestyle)
  "Matches the argument of \\mdfdefinestyle from mdframed package.")

;; Setup for \newmdtheoremenv & \mdtheorem

(TeX-auto-add-type "mdframed-mdtheorem" "LaTeX")

(defvar LaTeX-mdframed-mdtheorem-regexp
  `(,(concat
      "\\\\\\(new\\)?mdtheorem\\(?:env\\)?"
      "[ \t\n\r%]*"
      "\\(?:"
      (LaTeX-extract-key-value-label 'none)
      "\\)?"
      "[ \t\n\r%]*"
      "{\\([^}]+\\)}")
    (2 1) LaTeX-auto-mdframed-mdtheorem)
  "Matches the argument of \\newmdtheoremenv and \\mdtheorem from mdframed package.")

(defun LaTeX-mdframed-key-val-options ()
  "Return an updated list of key=vals from mdframed package.
This function retrieves values of user defined styles and colors
and prepends them to variable `LaTeX-mdframed-key-val-options'."
  (append
   (when (LaTeX-mdframed-mdfdefinestyle-list)
     (let ((val (copy-sequence
                 (cadr (assoc "style" LaTeX-mdframed-key-val-options)))))
       `(("style" ,(append
                    (mapcar #'car (LaTeX-mdframed-mdfdefinestyle-list))
                    val)))))
   ;; Check if any color defininig package is loaded and update the
   ;; key=values for coloring.  Prefer xcolor.sty if both packages are
   ;; loaded.  Run `TeX-style-list' only once and use
   ;; `TeX-active-styles' afterwards:
   (when (or (member "xcolor" (TeX-style-list))
             (member "color" TeX-active-styles))
     (let* ((colorcmd (if (member "xcolor" TeX-active-styles)
                          #'LaTeX-xcolor-definecolor-list
                        #'LaTeX-color-definecolor-list))
            (colors (mapcar #'car (funcall colorcmd)))
            (keys '("linecolor"
                    "innerlinecolor"
                    "middlelinecolor"
                    "outerlinecolor"
                    "backgroundcolor"
                    "fontcolor"
                    "shadowcolor"
                    "frametitlebackgroundcolor"
                    "subtitlebackgroundcolor"
                    "subtitleabovelinecolor"
                    "subtitlebelowlinecolor"))
            result)
       (dolist (key keys result)
         (cl-pushnew (list key colors) result :test #'equal))))
   LaTeX-mdframed-key-val-options))

(defun LaTeX-mdframed-auto-prepare ()
  "Clear variables before parsing for mdframed package."
  (setq LaTeX-auto-mdframed-newmdenv       nil
        LaTeX-auto-mdframed-mdfdefinestyle nil
        LaTeX-auto-mdframed-mdtheorem      nil))

(defun LaTeX-mdframed-auto-cleanup ()
  "Process parsed elements for mdframed package."
  (dolist (env (mapcar #'car (LaTeX-mdframed-newmdenv-list)))
    (LaTeX-add-environments
     `(,env LaTeX-env-args [TeX-arg-key-val (LaTeX-mdframed-key-val-options)] ))
    (TeX-ispell-skip-setcdr `((,env ispell-tex-arg-end 0))))
  (dolist (newenv (LaTeX-mdframed-mdtheorem-list))
    (let ((env (car newenv))
          (new (cadr newenv)))
      (LaTeX-add-environments (list env (vector "Heading")))
      (unless (and new (not (string= new "")))
        (LaTeX-add-environments (list (concat env "*") (vector "Heading")))))))

(add-hook 'TeX-auto-prepare-hook #'LaTeX-mdframed-auto-prepare t)
(add-hook 'TeX-auto-cleanup-hook #'LaTeX-mdframed-auto-cleanup t)
(add-hook 'TeX-update-style-hook #'TeX-auto-parse t)

(TeX-add-style-hook
 "mdframed"
 (lambda ()

   ;; Add mdframed to the parser
   (TeX-auto-add-regexp LaTeX-mdframed-newmdenv-regexp)
   (TeX-auto-add-regexp LaTeX-mdframed-mdfdefinestyle-regexp)
   (TeX-auto-add-regexp LaTeX-mdframed-mdtheorem-regexp)

   ;; 4. Commands
   (TeX-add-symbols
    '("mdfsetup"
      (TeX-arg-key-val (LaTeX-mdframed-key-val-options)))

    `("newmdenv"
      [TeX-arg-key-val (LaTeX-mdframed-key-val-options)]
      ,(lambda (optional)
         (let ((env (TeX-read-string
                     (TeX-argument-prompt optional nil "Environment"))))
           (LaTeX-add-environments
            `(,env LaTeX-env-args [TeX-arg-key-val (LaTeX-mdframed-key-val-options)]))
           ;; Add new env's to `ispell-tex-skip-alist': skip the optional argument
           (TeX-ispell-skip-setcdr `((,env ispell-tex-arg-end 0)))
           (TeX-argument-insert env optional))))

    '("renewmdenv"
      [TeX-arg-key-val (LaTeX-mdframed-key-val-options)]
      (TeX-arg-completing-read (LaTeX-mdframed-newmdenv-list) "Environment"))

    '("surroundwithmdframed"
      [TeX-arg-key-val (LaTeX-mdframed-key-val-options)]
      TeX-arg-environment)

    '("mdflength"
      (TeX-arg-completing-read ("skipabove"       "skipbelow"
                                "leftmargin"      "rightmargin"
                                "innerleftmargin" "innerrightmargin"
                                "innertopmargin"  "innerbottommargin"
                                "linewidth"       "innerlinewidth"
                                "middlelinewidth" "outerlinewidth")
                               "Length"))

    ;; 5. Defining your own style
    `("mdfdefinestyle"
      ,(lambda (optional)
         (let ((style (TeX-read-string
                       (TeX-argument-prompt optional nil "Style name"))))
           (LaTeX-add-mdframed-mdfdefinestyles style)
           (TeX-argument-insert style optional)))
      (TeX-arg-key-val (LaTeX-mdframed-key-val-options)))

    '("mdfapptodefinestyle"
      (TeX-arg-completing-read (LaTeX-mdframed-mdfdefinestyle-list) "Style name")
      (TeX-arg-key-val (LaTeX-mdframed-key-val-options)))

    ;; 6.11. Title commands inside the environment
    '("mdfsubtitle"
      [TeX-arg-key-val (LaTeX-mdframed-key-val-options)]
      "Subtitle")

    ;; 8. Theorems
    `("newmdtheoremenv"
      [TeX-arg-key-val (LaTeX-mdframed-key-val-options)]
      ,(lambda (optional)
         (let ((nthm (TeX-read-string
                      (TeX-argument-prompt optional nil "Environment"))))
           (LaTeX-add-environments (list nthm (vector "Heading")))
           (TeX-argument-insert nthm optional)))
      [TeX-arg-environment "Numbered like"]
      t [ (TeX-arg-eval progn (if (eq (save-excursion
                                        (backward-char 2)
                                        (preceding-char))
                                      ?\])
                                  ()
                                (TeX-arg-counter t "Within counter"))
                        "") ])

    `("mdtheorem"
      [TeX-arg-key-val (LaTeX-mdframed-key-val-options)]
      ,(lambda (optional)
         (let ((nthm (TeX-read-string
                      (TeX-argument-prompt optional nil "Environment"))))
           (LaTeX-add-environments (list nthm (vector "Heading"))
                                   (list (concat nthm "*") (vector "Heading")))
           (TeX-argument-insert nthm optional)))
      [TeX-arg-environment "Numbered like"]
      t [ (TeX-arg-eval progn (if (eq (save-excursion
                                        (backward-char 2)
                                        (preceding-char))
                                      ?\])
                                  ()
                                (TeX-arg-counter t "Within counter"))
                        "") ]))

   ;; Main environment defined by mdframed.sty
   (LaTeX-add-environments
    '("mdframed" LaTeX-env-args
      [TeX-arg-key-val (LaTeX-mdframed-key-val-options)] ))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("newmdenv"             "[{")
                                ("renewmdenv"           "[{")
                                ("surroundwithmdframed" "[{")
                                ("mdfsetup"             "[{")
                                ("mdfdefinestyle"       "{{")
                                ("mdfapptodefinestyle"  "{{")
                                ("newmdtheoremenv"      "[{[{[")
                                ("mdtheorem"            "[{[{["))
                              'function)
     (font-latex-add-keywords '(("mdfsubtitle"          "[{"))
                              'sectioning-5)
     (font-latex-add-keywords '(("mdflength"            "{"))
                              'variable)))
 TeX-dialect)

(defvar LaTeX-mdframed-package-options-list
  '(("xcolor")
    ("framemethod" ("default" "tex" "latex" "none" "0"
                    "tikz" "pgf" "1"
                    "pstricks" "ps" "postscript" "2"))
    ("tikz") ("TikZ")
    ("ps") ("pstricks") ("PSTricks"))
  "Package options for the framed package.")

(defun LaTeX-mdframed-package-options ()
  "Prompt for package options for the mdframed package."
  (TeX-read-key-val t LaTeX-mdframed-package-options-list))

;;; mdframed.el ends here
