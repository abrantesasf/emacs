;;; menukeys.el --- AUCTeX style for `menukeys.sty' (v1.4)  -*- lexical-binding: t; -*-

;; Copyright (C) 2016--2023 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2016-02-07
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

;; This file adds support for `menukeys.sty' (v1.4) from 2016/04/18.
;; `menukeys.sty' is part of TeXLive.

;;; Code:

;; Needed for auto-parsing:
(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(declare-function LaTeX-xcolor-definecolor-list "xcolor" ())

(defvar LaTeX-menukeys-input-separators-list
  '("/" "=" "*" "+" "," ";" ":" "-" ">" "<" "bslash")
  "List of input separators for macros of menukeys package.")

(defvar LaTeX-menukeys-predefined-styles-list
  '("menus" "roundedmenus" "angularmenus" "roundedkeys"
    "shadowedroundedkeys"  "angularkeys"  "shadowedangularkeys"
    "typewriterkeys"       "paths"        "pathswithfolder"
    "pathswithblackfolder" "hyphenatepaths"
    "hyphenatepathswithfolder"
    "hyphenatepathswithblackfolder")
  "List of predefined styles for macros from menukeys package.")

;; Setup for \newmenustyle(simple):
(TeX-auto-add-type "menukeys-newmenustyle" "LaTeX")

(defvar LaTeX-menukeys-newmenustyle-regexp
  '("\\\\\\(?:new\\|copy\\)menustyle\\(?:simple\\)?*?{\\([^}]+\\)}"
    1 LaTeX-auto-menukeys-newmenustyle)
  "Matches the argument of \\newmenustyle and
\\newmenustylesimple from menukeys package.")

;; Setup for \newmenucolortheme:
(TeX-auto-add-type "menukeys-newmenucolortheme" "LaTeX")

(defvar LaTeX-menukeys-newmenucolortheme-regexp
  '("\\\\\\(?:new\\|copy\\)menucolortheme{\\([^}]+\\)}"
    1 LaTeX-auto-menukeys-newmenucolortheme)
  "Matches the argument of \\newmenucolortheme from menukeys package.")

;; Setup for \newmenumacro:
(TeX-auto-add-type "menukeys-newmenumacro" "LaTeX")

(defvar LaTeX-menukeys-newmenumacro-regexp
  `(,(concat
      "\\\\\\(new\\|renew\\|provide\\)menumacro"
      "{?"
      (regexp-quote TeX-esc)
      "\\([a-zA-Z]+\\)"
      "}?"
      "\\(?:\\[\\([^]]*\\)\\]\\)?")
    (2 3 1) LaTeX-auto-menukeys-newmenumacro)
  "Matches the arguments of \\newmenumacro from menukeys package.")

(defun LaTeX-menukeys-auto-prepare ()
  "Clear various `LaTeX-auto-menukeys-*' variables before parsing."
  (setq LaTeX-auto-menukeys-newmenustyle nil
        LaTeX-auto-menukeys-newmenucolortheme nil
        LaTeX-auto-menukeys-newmenumacro nil))

(defun LaTeX-menukeys-auto-cleanup ()
  "Process the parsed elements for menukeys package.
This function adds parsed elements from the variable
`LaTeX-menukeys-newmenumacro-list' to AUCTeX via the function
`TeX-add-symbols'.  The variable
`LaTeX-menukeys-newmenumacro-list' and not the function with the
same name is used since this function looks for the order of
commands which are set by \\renewmenumacro in order to pick the
current separator.  These renew-commands are also removed first
from the variable `TeX-symbol-list' before being re-added."
  (dolist (x (apply #'append LaTeX-menukeys-newmenumacro-list))
    (let ((macro (nth 0 x))
          (sep   (nth 1 x))
          (renew (when (string= (nth 2 x) "renew")
                   (nth 2 x))))
      ;; When we are renewmenumacro'ing, delete the entry first from the
      ;; variable `TeX-symbol-list' and then add the new spec:
      (when renew
        (setq TeX-symbol-list
              (assq-delete-all (car (assoc macro (TeX-symbol-list))) TeX-symbol-list)))
      (TeX-add-symbols
       `(,macro [TeX-arg-completing-read
                 LaTeX-menukeys-input-separators-list
                 ,(concat "Input separator "
                          "(default "
                          (if (and sep (not (string= sep "")))
                              sep
                            ",")
                          ")")]
                t ))
      (when (and (featurep 'font-latex)
                 (eq TeX-install-font-lock 'font-latex-setup))
        (font-latex-add-keywords `((,macro "[{"))
                                 'textual)))))

(add-hook 'TeX-auto-prepare-hook #'LaTeX-menukeys-auto-prepare t)
(add-hook 'TeX-auto-cleanup-hook #'LaTeX-menukeys-auto-cleanup t)
(add-hook 'TeX-update-style-hook #'TeX-auto-parse t)

(defun TeX-arg-menukeys-newmenumacro (optional &optional renew)
  "Query and insert the arguments of \\newmenumacro from menukeys package.
After inserting, add the name of macro and the optional separator
to the name of known macros via `TeX-add-symbols'.  If
font-latex.el is loaded, also use `font-latex-add-keywords' on
macro.  If RENEW is non-nil, query for an already defined macro."
  (let ((macro (if renew
                   (completing-read
                    (concat "Macro: " TeX-esc)
                    (TeX-delete-duplicate-strings (mapcar #'car (LaTeX-menukeys-newmenumacro-list))))
                 (TeX-read-string (concat "Macro: " TeX-esc))))
        (sep   (completing-read
                (TeX-argument-prompt optional nil "Input separator (default ,)")
                LaTeX-menukeys-input-separators-list))
        (style (completing-read
                (TeX-argument-prompt optional nil "Style")
                (LaTeX-menukeys-newmenustyle-list))))
    (TeX-argument-insert (concat TeX-esc macro) optional)
    (when (and sep (not (string= sep "")))
      (insert (format "[%s]" sep)))
    (TeX-argument-insert style optional)
    ;; When we are renewmenumacro'ing, delete the entry first from the
    ;; variable `TeX-symbol-list' and then add the new spec:
    (when renew
      (setq TeX-symbol-list
            (assq-delete-all (car (assoc macro (TeX-symbol-list))) TeX-symbol-list)))
    (TeX-add-symbols
     `(,macro [TeX-arg-completing-read
               LaTeX-menukeys-input-separators-list
               ,(concat "Input separator "
                        "(default "
                        (if (and sep (not (string= sep "")))
                            sep
                          ",")
                        ")")]
              t))
    (when (and (featurep 'font-latex)
               (eq TeX-install-font-lock 'font-latex-setup))
      (font-latex-add-keywords `((,macro       "[{"))
                               'textual))))

(TeX-add-style-hook
 "menukeys"
 (lambda ()

   ;; Add menukeys to the parser
   (TeX-auto-add-regexp LaTeX-menukeys-newmenustyle-regexp)
   (TeX-auto-add-regexp LaTeX-menukeys-newmenucolortheme-regexp)
   (TeX-auto-add-regexp LaTeX-menukeys-newmenumacro-regexp)

   ;; Activate predefined stuff
   (apply #'LaTeX-add-menukeys-newmenustyles LaTeX-menukeys-predefined-styles-list)
   (LaTeX-add-menukeys-newmenucolorthemes "gray" "blacknwhite")

   ;; Run style hooks for xcolor, tikz and relsize
   (TeX-run-style-hooks "xcolor" "tikz" "relsize")

   ;; 4.1 Basic macros: These are not defined if the package option
   ;; definemenumacros ist set to false (default is true).  We check
   ;; for the package option here and add them.
   (unless (LaTeX-provided-package-options-member "menukeys" "definemenumacros=false")
     (TeX-add-symbols
      ;; \menu      [<separator>]{<sequence>}
      ;; \directory [<separator>]{path}
      ;; \keys      [<separator>]{keystrokes}
      '("menu"
        [TeX-arg-completing-read LaTeX-menukeys-input-separators-list
                                 "Input separator"]
        t)

      '("directory"
        [TeX-arg-completing-read LaTeX-menukeys-input-separators-list
                                 "Input separator"]
        t)

      '("keys"
        [TeX-arg-completing-read LaTeX-menukeys-input-separators-list
                                 "Input separator"]
        t)))

   (TeX-add-symbols
    ;; 4.2.1 Predefined styles
    ;; \drawtikzfolder[<front fill>][<draw>]
    '("drawtikzfolder"
      [TeX-arg-completing-read (LaTeX-xcolor-definecolor-list) "Front color"]
      [TeX-arg-completing-read (LaTeX-xcolor-definecolor-list) "Line color"])

    ;; 4.2.2 Declaring styles
    ;; \newmenustylesimple*{<name>}[<pre>]{<style>}[<sep>][<post>]{<theme>}
    `("newmenustylesimple"
      ,(lambda (optional)
         (let ((name (TeX-read-string
                      (TeX-argument-prompt optional nil "Name"))))
           (LaTeX-add-menukeys-newmenustyles name)
           (TeX-argument-insert name optional)))
      [ t ] nil [ nil ] [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    `("newmenustylesimple*"
      ,(lambda (optional)
         (let ((name (TeX-read-string
                      (TeX-argument-prompt optional nil "Name"))))
           (LaTeX-add-menukeys-newmenustyles name)
           (TeX-argument-insert name optional)))
      [ t ] nil [ nil ] [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    ;; \newmenustyle*{<name>}[<pre>]{<first>}[<sep>]{<mid>}{<last>}{<single>}[<post>]{<theme>}
    `("newmenustyle"
      ,(lambda (optional)
         (let ((name (TeX-read-string
                      (TeX-argument-prompt optional nil "Name"))))
           (LaTeX-add-menukeys-newmenustyles name)
           (TeX-argument-insert name optional)))
      [ t ] nil [ nil ] nil nil nil [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    `("newmenustyle*"
      ,(lambda (optional)
         (let ((name (TeX-read-string
                      (TeX-argument-prompt optional nil "Name"))))
           (LaTeX-add-menukeys-newmenustyles name)
           (TeX-argument-insert name optional)))
      [ t ] nil [ nil ] nil nil nil [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    '("CurrentMenuElement" 0)

    ;; 4.2.3 Copying styles
    `("copymenustyle"
      ,(lambda (optional)
         (let ((copy (TeX-read-string
                      (TeX-argument-prompt optional nil "Copy"))))
           (LaTeX-add-menukeys-newmenustyles copy)
           (TeX-argument-insert copy optional)))
      (TeX-arg-completing-read (LaTeX-menukeys-newmenustyle-list) "Original"))

    ;; 4.2.4 Changing styles
    ;; \changemenuelement*{name}{element}{definition}
    '("changemenuelement"
      (TeX-arg-completing-read (LaTeX-menukeys-newmenustyle-list) "Name")
      2)

    '("changemenuelement*"
      (TeX-arg-completing-read (LaTeX-menukeys-newmenustyle-list) "Name")
      2)

    ;; Same arguments as \newmenustylesimple
    '("renewmenustylesimple"
      (TeX-arg-completing-read (LaTeX-menukeys-newmenustyle-list) "Name")
      [ t ] nil [ nil ] [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    `("providemenustylesimple"
      ,(lambda (optional)
         (let ((name (TeX-read-string
                      (TeX-argument-prompt optional nil "Name"))))
           (LaTeX-add-menukeys-newmenustyles name)
           (TeX-argument-insert name optional)))
      [ t ] nil [ nil ] [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    ;; Same arguments as \newmenustyle
    '("providemenustyle"
      (TeX-arg-completing-read (LaTeX-menukeys-newmenustyle-list) "Name")
      [ t ] nil [ nil ] nil nil nil [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    `("renewmenustyle"
      ,(lambda (optional)
         (let ((name (TeX-read-string
                      (TeX-argument-prompt optional nil "Name"))))
           (LaTeX-add-menukeys-newmenustyles name)
           (TeX-argument-insert name optional)))
      [ t ] nil [ nil ] nil nil nil [ nil ]
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Color theme"))

    ;; 4.3 Color themes
    ;; 4.3.2 Create a theme
    ;; \newmenucolortheme{<name>}{<model>}{<bg>}{<br>}{<txt>}[<a>][<b>][<c>]
    `("newmenucolortheme"
      ,(lambda (optional)
         (let ((name (TeX-read-string
                      (TeX-argument-prompt optional nil "Name"))))
           (LaTeX-add-menukeys-newmenucolorthemes name)
           (TeX-argument-insert name optional)))
      (TeX-arg-completing-read (LaTeX-xcolor-color-models) "Model")
      (TeX-arg-conditional (save-excursion
                             (re-search-backward
                              "\\\\newmenucolortheme{[^}]+}{\\([^}]+\\)}"
                              (line-beginning-position) t)
                             (string= (match-string-no-properties 1) "named"))
          ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                    "Node background color"))
        ("Node background color spec"))
      (TeX-arg-conditional (save-excursion
                             (re-search-backward
                              "\\\\newmenucolortheme{[^}]+}{\\([^}]+\\)}"
                              (line-beginning-position) t)
                             (string= (match-string-no-properties 1) "named"))
          ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                    "Node border color"))
        ("Node border color spec"))
      (TeX-arg-conditional (save-excursion
                             (re-search-backward
                              "\\\\newmenucolortheme{[^}]+}{\\([^}]+\\)}"
                              (line-beginning-position) t)
                             (string= (match-string-no-properties 1) "named"))
          ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                    "Node text color"))
        ("Node text color spec"))
      (TeX-arg-conditional (y-or-n-p "With additional optional arguments? ")
          ( [ 3 ] )
        (ignore)))

    ;; 4.3.3 Copy a theme
    `("copymenucolortheme"
      ,(lambda (optional)
         (let ((copy (TeX-read-string
                      (TeX-argument-prompt optional nil "Copy"))))
           (LaTeX-add-menukeys-newmenucolorthemes copy)
           (TeX-argument-insert copy optional)))
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Original"))

    ;; 4.3.4 Change a theme
    '("changemenucolor"
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list) "Name")
      (TeX-arg-completing-read ("bg" "br" "txt") "Element")
      (TeX-arg-completing-read (LaTeX-xcolor-color-models) "Model")
      (TeX-arg-conditional (save-excursion
                             (re-search-backward
                              "\\\\changemenucolor{[^}]+}{[^}]+}{\\([^}]+\\)}"
                              (line-beginning-position) t)
                             (string= (match-string-no-properties 1) "named"))
          ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list) "Color"))
        ("Color spec")))

    ;; Same arguments as \newmenucolortheme
    '("renewmenucolortheme"
      (TeX-arg-completing-read (LaTeX-menukeys-newmenucolortheme-list)
                               "Name")
      (TeX-arg-completing-read (LaTeX-xcolor-color-models) "Model")
      (TeX-arg-conditional (save-excursion
                             (re-search-backward
                              "\\\\renewmenucolortheme{[^}]+}{\\([^}]+\\)}"
                              (line-beginning-position) t)
                             (string= (match-string-no-properties 1) "named"))
          ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                    "Node background color"))
        ("Node background color spec"))
      (TeX-arg-conditional (save-excursion
                             (re-search-backward
                              "\\\\renewmenucolortheme{[^}]+}{\\([^}]+\\)}"
                              (line-beginning-position) t)
                             (string= (match-string-no-properties 1) "named"))
          ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                    "Node border color"))
        ("Node border color spec"))
      (TeX-arg-conditional (save-excursion
                             (re-search-backward
                              "\\\\renewmenucolortheme{[^}]+}{\\([^}]+\\)}"
                              (line-beginning-position) t)
                             (string= (match-string-no-properties 1) "named"))
          ((TeX-arg-completing-read (LaTeX-xcolor-definecolor-list)
                                    "Node text color"))
        ("Node text color spec"))
      (TeX-arg-conditional (y-or-n-p "With additional optional arguments? ")
          ( [ 3 ] )
        (ignore)))

    ;; 4.4 Menu macros
    ;; 4.4.2 Defining or changing menu macros
    ;; \newmenumacro{<macro>} [<input sep>]{<style>}
    '("newmenumacro"     TeX-arg-menukeys-newmenumacro)
    '("providemenumacro" TeX-arg-menukeys-newmenumacro)
    '("renewmenumacro"   (TeX-arg-menukeys-newmenumacro t)))

   ;; 4.5 Keys: These macros are defined when definekeys option is not
   ;; false.
   ;; 0 : No argment, one macro
   ;; 1 : One argument, with completion
   ;; 2 : No argment, three macros: \<key>, \<key>win, \<key>mac
   (unless (LaTeX-provided-package-options-member "menukeys" "definekeys=false")
     (let ((keycmds '(("shift" . 0)   ("capslock" . 2)  ("tab" . 2)
                      ("esc" . 2)     ("ctrl" . 2)      ("alt" . 2)
                      ("AltGr" . 0)   ("cmd"   . 0)     ("Space" . 0)
                      ("SPACE" . 0)   ("return" . 2)    ("enter"  . 2)
                      ("winmenu" . 0) ("backspace" . 0) ("del" . 0)
                      ("arrowkeyup" . 0)   ("arrowkeydown" . 0)
                      ("arrowkeyleft" . 0) ("arrowkeyright" . 0)
                      ("arrowkey" . 1)
                      ;; Text inside some keys:
                      ("ctrlname" . 0) ("delname" . 0) ("spacename" . 0)))
           (os '("mac" "win"))
           collector)
       (dolist (cmd keycmds)
         (cond ((= (cdr cmd) 0)
                (push (car cmd) collector))
               ((= (cdr cmd) 1)
                (push (list (car cmd)
                            '(TeX-arg-completing-read  ("^" "v" ">" "<")
                                                       "Direction"))
                      collector))
               ((= (cdr cmd) 2)
                (push (car cmd) collector)
                (dolist (x os)
                  (push (concat (car cmd) x) collector)))))
       (apply #'TeX-add-symbols collector)))

   ;; Fontification:
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("menu"            "[{")
                                ("directory"       "[{")
                                ("keys"            "[{")
                                ("drawtikzfolder"  "[["))
                              'textual)
     (font-latex-add-keywords '(("newmenustylesimple"       "*{[{[[{")
                                ("newmenustyle"             "*{[{[{{{[{")
                                ("copymenustyle"            "{{")
                                ("changemenuelement"        "*{{{")
                                ("renewmenustylesimple"     "{[{[[{")
                                ("providemenustylesimple"   "{[{[[{")
                                ("providemenustyle"         "{[{[{{{[{")
                                ("renewmenustyle"           "{[{[{{{[{")
                                ("newmenucolortheme"        "{{{{{[[[")
                                ("copymenucolortheme"       "{{")
                                ("changemenucolor"          "{{{{")
                                ("renewmenucolortheme"      "{{{{{[[[")
                                ("newmenumacro"             "|{\\[{")
                                ("providemenumacro"         "|{\\[{")
                                ("renewmenumacro"           "|{\\[{"))
                              'function)))
 TeX-dialect)

(defvar LaTeX-menukeys-package-options-list
  '(("definemenumacros" ("true" "false"))
    ("definekeys"       ("true" "false"))
    ("mackeys"          ("text" "symbols"))
    ("os"               ("mac"  "win")))
  "Package options for menukeys package.")

(defun LaTeX-menukeys-package-options ()
  "Prompt for package options for the menukeys package."
  (TeX-read-key-val t LaTeX-menukeys-package-options-list))

;;; menukeys.el ends here
