;;; empheq.el --- AUCTeX style for `empheq.sty' (v2.14)  -*- lexical-binding: t; -*-

;; Copyright (C) 2016-2022 Free Software Foundation, Inc.

;; Author: Arash Esbati <arash@gnu.org>
;; Maintainer: auctex-devel@gnu.org
;; Created: 2016-08-07
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

;; This file adds support for `empheq.sty' (v2.14) from 2014/08/04.
;; `empheq.sty' is part of TeXLive.

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(declare-function LaTeX-item-equation-alignat
                  "amsmath" (&optional suppress))

(defvar LaTeX-mathtools-package-options)

(defvar LaTeX-empheq-key-val-options
  `(("box")
    ("innerbox")
    ("left" ,(mapcar
              (lambda (x)
                (concat TeX-esc x))
              '("empheqlbrace"
                "empheqlbrack"
                "empheqlangle"
                "empheqlparen"
                "empheqlvert"
                "empheqlVert"
                "empheqlfloor"
                "empheqlceil"
                "empheqbiglbrace"
                "empheqbiglbrack"
                "empheqbiglangle"
                "empheqbiglparen"
                "empheqbiglvert"
                "empheqbiglVert"
                "empheqbiglfloor"
                "empheqbiglceil")))
    ("right" ,(mapcar
               (lambda (x)
                 (concat TeX-esc x))
               '("empheqrbrace"
                 "empheqrbrack"
                 "empheqrangle"
                 "empheqrparen"
                 "empheqrvert"
                 "empheqrVert"
                 "empheqrfloor"
                 "empheqrceil"
                 "empheqbigrbrace"
                 "empheqbigrbrack"
                 "empheqbigrangle"
                 "empheqbigrparen"
                 "empheqbigrvert"
                 "empheqbigrVert"
                 "empheqbigrfloor"
                 "empheqbigrceil")))
    ("outerbox")
    ("marginbox"))
  "Key=value options for environments from empheq.sty.")

(defvar LaTeX-empheq-supported-amsmath-envs
  '("equation"  "equation*"
    "align"     "align*"
    "gather"    "gather*"
    "flalign"   "flalign*"
    "alignat"   "alignat*"
    "multline"  "multline*")
  "List of amsmath environments supported by empheq package.")

(defvar LaTeX-empheq-package-options
  '("overload" "overload2" "ntheorem" "newmultline" "oldmultline")
  "Package options for the empheq package.")
(TeX-load-style "mathtools")
;; Add elements from `LaTeX-mathtools-package-options' only once
;; and not every time the style hook runs
(dolist (elt LaTeX-mathtools-package-options)
  (add-to-list 'LaTeX-empheq-package-options elt))

;; Setup for \Declare(Left|Right)Delimiter:

(TeX-auto-add-type "empheq-declaredelimiter" "LaTeX")

(defvar LaTeX-empheq-declaredelimiter-regexp
  `(,(concat "\\\\Declare\\(Left\\|Right\\)Delimiter"
             "[ \t\n\r%]*"
             "\\(?:\\[[^]]*\\]\\)?"
             "[ \t\n\r%]*"
             "{"
             (regexp-quote TeX-esc)
             "\\([^}]+\\)}")
    (2 1) LaTeX-auto-empheq-declaredelimiter)
  "Matches the argument of \\Declare(Left|Right)Delimiter from empheq package.")

(defun LaTeX-empheq-auto-prepare ()
  "Clear `LaTeX-auto-empheq-declaredelimiter' before parsing."
  (setq LaTeX-auto-empheq-declaredelimiter nil))

(defun LaTeX-empheq-auto-cleanup ()
  "Process parsed delimiters."
  (dolist (delim (mapcar #'car (LaTeX-empheq-declaredelimiter-list)))
    (TeX-add-symbols (concat "empheq" delim)
                     (concat "empheqbig" delim))))

(add-hook 'TeX-auto-prepare-hook #'LaTeX-empheq-auto-prepare t)
(add-hook 'TeX-auto-cleanup-hook #'LaTeX-empheq-auto-cleanup t)
(add-hook 'TeX-update-style-hook #'TeX-auto-parse t)

(defun LaTeX-empheq-key-val-options ()
  "Return an updated list of key=vals from empheq package.
This function retrieves values of user defined left and right
delimiters and prepends them to variable
`LaTeX-empheq-key-val-options'."
  (append
   (when (LaTeX-empheq-declaredelimiter-list)
     (let ((lvals (copy-sequence
                   (cadr (assoc "left" LaTeX-empheq-key-val-options))))
           (rvals (copy-sequence
                   (cadr (assoc "right" LaTeX-empheq-key-val-options)))))
       (dolist (delims (LaTeX-empheq-declaredelimiter-list))
         (let ((delim (car delims))
               (where (cadr delims)))
           (if (string= where "Left")
               (progn
                 (cl-pushnew (concat TeX-esc "empheq" delim)    lvals :test #'equal)
                 (cl-pushnew (concat TeX-esc "empheqbig" delim) lvals :test #'equal))
             (cl-pushnew (concat TeX-esc "empheq" delim)    rvals :test #'equal)
             (cl-pushnew (concat TeX-esc "empheqbig" delim) rvals :test #'equal))))
       `(("left" ,lvals)
         ("right" ,rvals))))
   LaTeX-empheq-key-val-options))

(defun LaTeX-empheq-env (optional)
  "Insert a label inside empheq environment.
In addition, query for a column number for the alignat*?
environments and insert suitable number of ampersands.  If
OPTIONAL is non-nil, indicate it in the prompt."
  (save-excursion
    (TeX-looking-at-backward (concat TeX-grop "\\([^" TeX-grcl "]+\\)" TeX-grcl)
                             20))
  (let* ((amsenv (match-string-no-properties 1))
         ncols)
    (when (string-match-p "\\`alignat" amsenv)
      (setq ncols (read-number
                   (TeX-argument-prompt optional nil "Number of columns")))
      (save-excursion
        (goto-char (match-end 1))
        (insert "=" (number-to-string ncols))
        (goto-char TeX-exit-mark)
        (insert-char ?& (+ ncols ncols -1))
        (indent-according-to-mode)))
    (save-excursion
      (goto-char TeX-exit-mark)
      (beginning-of-line)
      (when (and (assoc amsenv LaTeX-label-alist)
                 (LaTeX-label amsenv 'environment))
        (indent-according-to-mode)
        (LaTeX-newline)
        (indent-according-to-mode)))))

(defun LaTeX-empheq-item-equation ()
  "Insert contents to terminate a line in multi-line equations environment.
Put line break macro on the last line.  Next, if the current
environment wants \\label, insert it also.  And insert suitable
number of ampersands if possible."
  (let ((env "empheq")
        amsenv ncols match)
    (save-excursion
      (LaTeX-find-matching-begin)
      (re-search-forward (concat (regexp-quote TeX-esc)
                                 "begin" TeX-grop env TeX-grcl))
      (when (looking-at "[ \t\n\r%]*\\[")
        (forward-sexp))
      (re-search-forward "[ \t\n\r%]*{\\([^}]+\\)}")
      (setq match (replace-regexp-in-string "[ \t\n\r%]" ""
                                            (match-string-no-properties 1)))
      (if (string-match "=" match)
          (progn
            (setq amsenv (car (split-string match "=")))
            (setq ncols (string-to-number (cadr (split-string match "=")))))
        (setq amsenv match)))
    ;; Do not ask for "\\" if in "equation" or "equation*" since these
    ;; are single line equations only
    (if (member amsenv '("equation" "equation*"))
        ;; Nullify the effect of `M-RET'
        (progn
          (message "This environment does not support multi-line equations")
          (end-of-line 0)
          (kill-line 1))
      (end-of-line 0)
      (just-one-space)
      (TeX-insert-macro "\\")
      (forward-line 1)
      (indent-according-to-mode))
    ;; Add a new label only if not in "equation"
    (when (and (not (string= amsenv "equation"))
               (assoc amsenv LaTeX-label-alist)
               (LaTeX-label amsenv 'environment))
      (LaTeX-newline)
      (indent-according-to-mode))
    (when ncols
      (save-excursion
        (insert-char ?& (+ ncols ncols -1))))))

(TeX-add-style-hook
 "empheq"
 (lambda ()

   ;; Add empheq to parser
   (TeX-auto-add-regexp LaTeX-empheq-declaredelimiter-regexp)

   ;; Load amsmath.el and mathtools.el
   (TeX-run-style-hooks "amsmath" "mathtools")

   (LaTeX-add-environments
    '("empheq" LaTeX-env-args
      [TeX-arg-key-val (LaTeX-empheq-key-val-options)]
      (TeX-arg-completing-read LaTeX-empheq-supported-amsmath-envs
                               "amsmath environment")
      LaTeX-empheq-env))

   ;; Add "empheq" to `LaTeX-item-list' and run
   ;; `LaTeX-empheq-item-equation' when `M-RET' is invoked
   (add-to-list 'LaTeX-item-list '("empheq" . LaTeX-empheq-item-equation) t)

   ;; Reftex support: Use `reftex-add-label-environments'
   (when (fboundp 'reftex-add-label-environments)
     (reftex-add-label-environments '(("empheq" ?e nil nil t))))

   (TeX-add-symbols
    '("empheqset" (TeX-arg-key-val (LaTeX-empheq-key-val-options)))

    ;; 1.4 Special delimiters
    ;; Normal
    '("empheqlbrace" TeX-arg-insert-right-brace-maybe)
    '("empheqrbrace")
    '("empheqlbrack" TeX-arg-insert-right-brace-maybe)
    '("empheqrbrack")
    '("empheqlangle" TeX-arg-insert-right-brace-maybe)
    '("empheqrangle")
    '("empheqlparen" TeX-arg-insert-right-brace-maybe)
    '("empheqrparen")
    '("empheqlvert" TeX-arg-insert-right-brace-maybe)
    '("empheqrvert")
    '("empheqlVert" TeX-arg-insert-right-brace-maybe)
    '("empheqrVert")
    '("empheqlfloor" TeX-arg-insert-right-brace-maybe)
    '("empheqrfloor")
    '("empheqlceil" TeX-arg-insert-right-brace-maybe)
    '("empheqrceil")
    ;; Bigger
    '("empheqbiglbrace" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrbrace")
    '("empheqbiglbrack" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrbrack")
    '("empheqbiglangle" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrangle")
    '("empheqbiglparen" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrparen")
    '("empheqbiglvert" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrvert")
    '("empheqbiglVert" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrVert")
    '("empheqbiglfloor" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrfloor")
    '("empheqbiglceil" TeX-arg-insert-right-brace-maybe)
    '("empheqbigrceil"))

   ;; Append delimiters to `TeX-braces-association'
   (make-local-variable 'TeX-braces-association)
   (let ((delimiters '(("\\empheqlbrace" . "\\empheqrbrace")
                       ("\\empheqlbrack" . "\\empheqrbrack")
                       ("\\empheqlangle" . "\\empheqrangle")
                       ("\\empheqlparen" . "\\empheqrparen")
                       ("\\empheqlvert"  . "\\empheqrvert")
                       ("\\empheqlVert"  . "\\empheqrVert")
                       ("\\empheqlfloor" . "\\empheqrfloor")
                       ("\\empheqlceil"  . "\\empheqrceil")
                       ("\\empheqbiglbrace" . "\\empheqbigrbrace")
                       ("\\empheqbiglbrack" . "\\empheqbigrbrack")
                       ("\\empheqbiglangle" . "\\empheqbigrangle")
                       ("\\empheqbiglparen" . "\\empheqbigrparen")
                       ("\\empheqbiglvert"  . "\\empheqbigrvert")
                       ("\\empheqbiglVert"  . "\\empheqbigrVert")
                       ("\\empheqbiglfloor" . "\\empheqbigrfloor")
                       ("\\empheqbiglceil"  . "\\empheqbigrceil"))))
     (dolist (elt delimiters)
       (add-to-list 'TeX-braces-association elt t)))

   ;; 2.2.1 Using multline
   (when (LaTeX-provided-package-options-member "empheq" "oldmultline")
     (LaTeX-add-environments
      '("MTmultlined" LaTeX-mathtools-env-multlined)))

   ;; 2.2.2 The overload option
   ;; I simplify it and ignore the additional feature overload2:
   (when (or (LaTeX-provided-package-options-member "empheq" "overload")
             (LaTeX-provided-package-options-member "empheq" "overload2"))
     (LaTeX-add-environments
      '("align"      LaTeX-env-label-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      `("alignat"    LaTeX-env-args
        "Number of columns"
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"]
        ,(lambda (_)
           (goto-char TeX-exit-mark)
           (beginning-of-line)
           (LaTeX-item-equation-alignat t)
           (end-of-line 0)
           (indent-according-to-mode)
           (goto-char TeX-exit-mark)))

      '("equation"   LaTeX-env-label-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      '("flalign"    LaTeX-env-label-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      '("gather"     LaTeX-env-label-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      '("multline"   LaTeX-env-label-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      '("align*"     LaTeX-env-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      `("alignat*"   LaTeX-env-args
        "Number of columns"
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"]
        ,(lambda (_)
           (goto-char TeX-exit-mark)
           (LaTeX-item-equation-alignat t)))

      '("equation*"  LaTeX-env-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      '("flalign*"   LaTeX-env-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      '("gather*"    LaTeX-env-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      '("multline*"  LaTeX-env-args
        [TeX-arg-key-val (LaTeX-empheq-key-val-options) "empheq options"])

      ;; Original definitions are stored prefixed with "AmS"
      '("AmSalign"      LaTeX-env-label)
      '("AmSalignat"    LaTeX-amsmath-env-alignat)
      '("AmSequation"   LaTeX-env-label)
      '("AmSflalign"    LaTeX-env-label)
      '("AmSgather"     LaTeX-env-label)
      '("AmSmultline"   LaTeX-env-label)
      '("AmSalign*")
      '("AmSalignat*"   LaTeX-amsmath-env-alignat)
      '("AmSequation*")
      '("AmSflalign*")
      '("AmSgather*")
      '("AmSmultline*"))

     ;; Append original definitions to `LaTeX-label-alist'
     (let ((envs '("AmSalign"
                   "AmSalignat"
                   "AmSequation"
                   "AmSflalign"
                   "AmSgather"
                   "AmSmultline")))
       (dolist (env envs)
         (add-to-list 'LaTeX-label-alist `(,env . LaTeX-amsmath-label) t)))

     ;; RefTeX support: Add original definitions with `reftex-add-label-environments'
     (when (fboundp 'reftex-add-label-environments)
       (reftex-add-label-environments
        '(("AmSalign"     ?e nil nil eqnarray-like)
          ("AmSequation"  ?e nil nil t)
          ("AmSgather"    ?e nil nil eqnarray-like)
          ("AmSmultline"  ?e nil nil t)
          ("AmSflalign"   ?e nil nil eqnarray-like)
          ("AmSalignat"   ?e nil nil alignat-like))))

     ;; Append original definitions to `LaTeX-item-list'; functions
     ;; are provided by amsmath.el
     (let ((envs '(("AmSalign" . LaTeX-item-equation)
                   ("AmSalign*" . LaTeX-item-equation)
                   ("AmSflalign" . LaTeX-item-equation)
                   ("AmSalignat" . LaTeX-item-equation-alignat)
                   ("AmSalignat*" . LaTeX-item-equation-alignat)
                   ("AmSflalign*" . LaTeX-item-equation)
                   ("AmSgather" . LaTeX-item-equation)
                   ("AmSgather*" . LaTeX-item-equation)
                   ("AmSmultline" . LaTeX-item-equation)
                   ("AmSmultline*" . LaTeX-item-equation))))
       (dolist (env envs)
         (add-to-list 'LaTeX-item-list env t)))

     ;; Ispell skip lists:
     (TeX-ispell-skip-setcdr
      `(,(cons (concat "\\(AmS\\(?:align\\(?:\\*\\|at\\*?\\)?\\|"
                       "equation\\*?\\|flalign\\*?\\|gather\\*?\\|multline\\*?\\)\\)")
               (concat "\\\\end{"
                       "\\(AmS\\(?:align\\(?:\\*\\|at\\*?\\)?\\|"
                       "equation\\*?\\|flalign\\*?\\|gather\\*?\\|multline\\*?\\)\\)}")))))

   ;; 3.2 Support for ntheorem
   (LaTeX-add-lengths "mintagvsep")

   ;; 4.1 Creating your own delimiters
   (TeX-add-symbols
    `("DeclareLeftDelimiter"
      [ "Space adjustment" ]
      ,(lambda (optional)
         (let ((delim (TeX-read-string
                       (TeX-argument-prompt optional nil "Delimiter: \\" t))))
           (TeX-add-symbols (concat "empheq" delim)
                            (concat "empheqbig" delim))
           (LaTeX-add-empheq-declaredelimiters `(,delim "Left"))
           (TeX-argument-insert delim optional TeX-esc))))

    `("DeclareRightDelimiter"
      [ "Space adjustment" ]
      ,(lambda (optional)
         (let ((delim (TeX-read-string
                       (TeX-argument-prompt optional nil "Delimiter: \\" t))))
           (TeX-add-symbols (concat "empheq" delim)
                            (concat "empheqbig" delim))
           (LaTeX-add-empheq-declaredelimiters `(,delim "Right"))
           (TeX-argument-insert delim optional TeX-esc)))))

   ;; 4.2 Fine-tuning of delimiters
   (LaTeX-add-lengths "EmphEqdelimitershortfall")
   (LaTeX-add-counters "EmphEqdelimiterfactor")

   (TeX-add-symbols
    ;; 4.3 Scaling material yourself
    '("EmphEqdisplayheight" 0)
    '("EmphEqdisplaydepth"  0)
    ;; 6.1 New empheq-like environments
    '("EmphEqMainEnv" 0)
    '("endEmphEqMainEnv" 0))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("empheqset"             "{")
                                ("DeclareLeftDelimiter"  "[{")
                                ("DeclareRightDelimiter" "[{"))
                              'function)))
 TeX-dialect)

;;; empheq.el ends here
