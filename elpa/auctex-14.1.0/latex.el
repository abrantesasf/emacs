;;; latex.el --- Support for LaTeX documents.  -*- lexical-binding: t; -*-

;; Copyright (C) 1991, 1993-2025 Free Software Foundation, Inc.

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

;; This file provides AUCTeX support for LaTeX.

;;; Code:

(require 'tex)
(require 'tex-style)
(require 'tex-ispell)
(require 'latex-flymake)

;; Silence the compiler for functions:
(declare-function multi-prompt "multi-prompt")
(declare-function multi-prompt-key-value "multi-prompt")
(declare-function LaTeX-install-toolbar "tex-bar" nil)
(declare-function outline-level "ext:outline" nil)
(declare-function outline-mark-subtree "ext:outline" nil)
(declare-function turn-off-filladapt-mode "ext:filladapt" nil)

;; Silence the compiler for variables:
(defvar outline-heading-alist)
(defvar LaTeX-section-list-changed)

;;; Syntax

(defvar LaTeX-optop "["
  "The LaTeX optional argument opening character.")

(defvar LaTeX-optcl "]"
  "The LaTeX optional argument closeing character.")

;;; Style

(defcustom LaTeX-default-style "article"
  "Default when creating new documents."
  :group 'LaTeX-environment
  :type 'string)

(defcustom LaTeX-default-options nil
  "Default options to documentclass.
A comma-seperated list of strings."
  :group 'LaTeX-environment
  :type '(repeat (string :format "%v"))
  :local t)

(defcustom LaTeX-insert-into-comments nil
  "Whether insertion commands stay in comments.
This allows using the insertion commands even when the lines are
outcommented, like in dtx files."
  :group 'LaTeX-environment
  :type 'boolean
  :safe #'booleanp
  :package-version '(auctex . "14.0.8"))

(defcustom docTeX-indent-across-comments nil
  "If non-nil, indentation in docTeX is done across comments."
  :group 'LaTeX-indentation
  :type 'boolean)

(defun LaTeX-newline ()
  "Start a new line potentially staying within comments.
This depends on `LaTeX-insert-into-comments'."
  (interactive)
  (if LaTeX-insert-into-comments
      (cond ((and (save-excursion (skip-chars-backward " \t") (bolp))
                  (save-excursion
                    (skip-chars-forward " \t")
                    (looking-at (concat TeX-comment-start-regexp "+"))))
             (beginning-of-line)
             (insert (buffer-substring-no-properties
                      (line-beginning-position) (match-end 0)))
             (newline))
            ((and (not (bolp))
                  (save-excursion
                    (skip-chars-forward " \t") (not (TeX-escaped-p)))
                  (looking-at
                   (concat "[ \t]*" TeX-comment-start-regexp "+[ \t]*")))
             (delete-region (match-beginning 0) (match-end 0))
             (indent-new-comment-line))
            ;; `indent-new-comment-line' does nothing when
            ;; `comment-auto-fill-only-comments' is non-nil, so we
            ;; must be sure to be in a comment before calling it.  In
            ;; any other case `newline' is used.
            ((TeX-in-comment)
             (indent-new-comment-line))
            (t
             (newline)))
    (newline)))


;;; Syntax Table

(defvar LaTeX-mode-syntax-table (make-syntax-table TeX-mode-syntax-table)
  "Syntax table used in LaTeX mode.")

(progn ; set [] to match for LaTeX.
  (modify-syntax-entry (string-to-char LaTeX-optop)
                       (concat "(" LaTeX-optcl)
                       LaTeX-mode-syntax-table)
  (modify-syntax-entry (string-to-char LaTeX-optcl)
                       (concat ")" LaTeX-optop)
                       LaTeX-mode-syntax-table))

;;; Sections

;; Declare dynamically scoped vars.
(defvar LaTeX-title nil "Dynamically bound by `LaTeX-section'.")
(defvar LaTeX-name nil "Dynamically bound by `LaTeX-section'.")
(defvar LaTeX-level nil "Dynamically bound by `LaTeX-section'.")
(defvar LaTeX-done-mark nil "Dynamically bound by `LaTeX-section'.")
(defvar LaTeX-toc nil "Dynamically bound by `LaTeX-section'.")

(defun LaTeX-section (arg)
  "Insert a template for a LaTeX section.
Determine the type of section to be inserted, by the argument ARG.

If ARG is nil or missing, use the current level.
If ARG is a list (selected by \\[universal-argument]), go downward one level.
If ARG is negative, go up that many levels.
If ARG is positive or zero, use absolute level:

  0 : part
  1 : chapter
  2 : section
  3 : subsection
  4 : subsubsection
  5 : paragraph
  6 : subparagraph

The following variables can be set to customize:

`LaTeX-section-hook'    Hooks to run when inserting a section.
`LaTeX-section-label'   Prefix to all section labels."

  (interactive "*P")
  (let* ((val (prefix-numeric-value arg))
         (LaTeX-level (cond ((null arg)
                             (LaTeX-current-section))
                            ((listp arg)
                             (LaTeX-down-section))
                            ((< val 0)
                             (LaTeX-up-section (- val)))
                            (t val)))
         (LaTeX-name (LaTeX-section-name LaTeX-level))
         (LaTeX-toc nil)
         (LaTeX-title (if (TeX-active-mark)
                          (buffer-substring (region-beginning)
                                            (region-end))
                        ""))
         (LaTeX-done-mark (make-marker)))
    (run-hooks 'LaTeX-section-hook)
    (LaTeX-newline)
    (if (marker-position LaTeX-done-mark)
        (goto-char (marker-position LaTeX-done-mark)))
    (set-marker LaTeX-done-mark nil)))

(defun LaTeX-current-section ()
  "Return the level of the section that contain point.
See also `LaTeX-section' for description of levels."
  (save-excursion
    (max (LaTeX-largest-level)
         (if (re-search-backward (LaTeX-outline-regexp) nil t)
             (- (LaTeX-outline-level) (LaTeX-outline-offset))
           (LaTeX-largest-level)))))

(defun LaTeX-down-section ()
  "Return the value of a section one level under the current.
Tries to find what kind of section that have been used earlier in the
text, if this fail, it will just return one less than the current
section."
  (save-excursion
    (let ((current (LaTeX-current-section))
          (next nil)
          (regexp (LaTeX-outline-regexp)))
      (if (not (re-search-backward regexp nil t))
          (1+ current)
        (while (not next)
          (cond
           ((eq (LaTeX-current-section) current)
            (if (re-search-forward regexp nil t)
                (if (<= (setq next (LaTeX-current-section)) current) ;Wow!
                    (setq next (1+ current)))
              (setq next (1+ current))))
           ((not (re-search-backward regexp nil t))
            (setq next (1+ current)))))
        next))))

(defun LaTeX-up-section (arg)
  "Return the value of the section ARG levels above this one."
  (save-excursion
    (if (zerop arg)
        (LaTeX-current-section)
      (let ((current (LaTeX-current-section)))
        (while (and (>= (LaTeX-current-section) current)
                    (re-search-backward (LaTeX-outline-regexp)
                                        nil t)))
        (LaTeX-up-section (1- arg))))))

(defvar LaTeX-section-list '(("part" 0)
                             ("chapter" 1)
                             ("section" 2)
                             ("subsection" 3)
                             ("subsubsection" 4)
                             ("paragraph" 5)
                             ("subparagraph" 6))
  "List which elements is the names of the sections used by LaTeX.")

(defvar-local LaTeX-section-menu nil)

(defun LaTeX-section-list-add-locally (sections &optional clean)
  "Add SECTIONS to `LaTeX-section-list'.
SECTIONS can be a single list containing the section macro name
as a string and the level as an integer or a list of such lists.

If optional argument CLEAN is non-nil, remove any existing
entries from `LaTeX-section-list' before adding the new ones.

The function will make `LaTeX-section-list' buffer-local and
invalidate the section submenu in order to let the menu filter
regenerate it.  It is mainly a convenience function which can be
used in style files."
  (when (stringp (car sections))
    (setq sections (list sections)))
  (make-local-variable 'LaTeX-section-list)
  (when clean (setq LaTeX-section-list nil))
  (dolist (elt sections) (add-to-list 'LaTeX-section-list elt t))
  (setq LaTeX-section-list
        (sort (copy-sequence LaTeX-section-list)
              (lambda (a b) (< (nth 1 a) (nth 1 b)))))
  (setq LaTeX-section-menu nil))

(defun LaTeX-section-name (level)
  "Return the name of the section corresponding to LEVEL."
  (car (rassoc (list level) LaTeX-section-list)))

(defun LaTeX-section-level (name)
  "Return the level of the section NAME.
NAME can be starred variant."
  (if (string-suffix-p "*" name)
      (setq name (substring-no-properties name 0 -1)))
  (cadr (assoc name LaTeX-section-list)))

(defcustom TeX-outline-extra nil
  "List of extra TeX outline levels.

Each element is a list with two entries.  The first entry is the
regular expression matching a header, and the second is the level of
the header.  See `LaTeX-section-list' for existing header levels."
  :group 'LaTeX
  :type '(repeat (group (regexp :tag "Match")
                        (integer :tag "Level"))))

(defun LaTeX-outline-regexp (&optional anywhere)
  "Return regexp for LaTeX sections.

If optional argument ANYWHERE is not nil, do not require that the
header is at the start of a line."
  (concat (if anywhere "" "^")
          "[ \t]*"
          (regexp-quote TeX-esc)
          "\\(appendix\\|documentstyle\\|documentclass\\|"
          (mapconcat #'car LaTeX-section-list "\\|")
          "\\)\\b"
          (if TeX-outline-extra
              "\\|"
            "")
          (mapconcat #'car TeX-outline-extra "\\|")
          "\\|" TeX-header-end
          "\\|" TeX-trailer-start))

(defvar-local LaTeX-largest-level nil
  "Largest sectioning level with current document class.")

(defun LaTeX-largest-level ()
  "Return largest sectioning level with current document class.
Run style hooks before it has not been done."
  (TeX-update-style)
  LaTeX-largest-level)

(defun LaTeX-largest-level-set (section)
  "Set `LaTeX-largest-level' to the level of SECTION.
SECTION has to be a string contained in `LaTeX-section-list'.
Additionally the function will invalidate the section submenu in
order to let the menu filter regenerate it."
  (setq LaTeX-largest-level (LaTeX-section-level section))
  (let ((offset (LaTeX-outline-offset)))
    (when (> offset 0)
      (let (lst)
        (dolist (tup outline-heading-alist)
          (setq lst (cons (cons (car tup)
                                (+ offset (cdr tup)))
                          lst)))
        (setq outline-heading-alist (nreverse lst)))))
  (setq LaTeX-section-menu nil))

(defun LaTeX-outline-offset ()
  "Offset to add to `LaTeX-section-list' levels to get outline level."
  (- 2 (LaTeX-largest-level)))

(defun TeX-look-at (list)
  "Check if we are looking at the first element of a member of LIST.
If so, return the second element, otherwise return nil."
  (while (and list
              (not (looking-at (nth 0 (car list)))))
    (setq list (cdr list)))
  (if list
      (nth 1 (car list))
    nil))

(defvar LaTeX-header-end
  (concat "^[^%\n]*" (regexp-quote TeX-esc) "begin *"
          TeX-grop "document" TeX-grcl)
  "Default end of header marker for LaTeX documents.")

(defvar LaTeX-trailer-start
  (concat "^[^%\n]*" (regexp-quote TeX-esc) "end *"
          TeX-grop "document" TeX-grcl)
  "Default start of trailer marker for LaTeX documents.")

(defun LaTeX-outline-level ()
  "Find the level of current outline heading in an LaTeX document."
  (cond ((looking-at LaTeX-header-end) 1)
        ((looking-at LaTeX-trailer-start) 1)
        ((TeX-look-at TeX-outline-extra)
         (max 1 (+ (TeX-look-at TeX-outline-extra)
                   (LaTeX-outline-offset))))
        (t
         (save-excursion
           (skip-chars-forward " \t")
           (forward-char 1)
           (cond ((looking-at "appendix") 1)
                 ((looking-at "documentstyle") 1)
                 ((looking-at "documentclass") 1)
                 ((TeX-look-at LaTeX-section-list)
                  (max 1 (+ (TeX-look-at LaTeX-section-list)
                            (LaTeX-outline-offset))))
                 (t (outline-level)))))))

(defun LaTeX-outline-name ()
  "Guess a name for the current header line."
  (save-excursion
    (search-forward "{" nil t)
    (let ((beg (point)))
      (backward-char)
      (condition-case nil
          (with-syntax-table (TeX-search-syntax-table ?\{ ?\})
            (forward-sexp)
            (backward-char))
        (error (forward-sentence)))
      (replace-regexp-in-string "[\n\r][ ]*" " "
                                (buffer-substring beg (point))))))

(add-hook 'TeX-remove-style-hook
          (lambda () (setq LaTeX-largest-level nil)))

(defcustom LaTeX-section-hook
  '(LaTeX-section-heading
    LaTeX-section-title
    ;; LaTeX-section-toc                ; Most people won't want this
    LaTeX-section-section
    LaTeX-section-label)
  "List of hooks to run when a new section is inserted.

The following variables are set before the hooks are run

`LaTeX-level'     - numeric section level, see the documentation of
                    `LaTeX-section'.
`LaTeX-name'      - name of the sectioning command, derived from
                    `LaTeX-level'.
`LaTeX-title'     - The title of the section, default to an empty
                    string.
`LaTeX-toc'       - Entry for the table of contents list, default
                    nil.
`LaTeX-done-mark' - Position of point afterwards, default nil
                    (meaning end).

The following standard hooks exist -

`LaTeX-section-heading': Query the user about the name of the
sectioning command.  Modifies `LaTeX-level' and `LaTeX-name'.

`LaTeX-section-title': Query the user about the title of the
section.  Modifies `LaTeX-title'.

`LaTeX-section-toc': Query the user for the toc entry.  Modifies
`LaTeX-toc'.

`LaTeX-section-section': Insert LaTeX section command according to
`LaTeX-name', `LaTeX-title', and `LaTeX-toc'.  If `LaTeX-toc' is
nil, no toc entry is inserted.  If `LaTeX-toc' or `LaTeX-title'
are empty strings, `LaTeX-done-mark' will be placed at the point
they should be inserted.

`LaTeX-section-label': Insert a label after the section command.
Controled by the variable `LaTeX-section-label'.

To get a full featured `LaTeX-section' command, insert

 (setq LaTeX-section-hook
       \\='(LaTeX-section-heading
         LaTeX-section-title
         LaTeX-section-toc
         LaTeX-section-section
         LaTeX-section-label))

in your init file such as .emacs.d/init.el or .emacs."
  :group 'LaTeX-macro
  :type 'hook
  :options '(LaTeX-section-heading
             LaTeX-section-title
             LaTeX-section-toc
             LaTeX-section-section
             LaTeX-section-label))


(defcustom LaTeX-section-label
  '(("part" . "part:")
    ("chapter" . "chap:")
    ("section" . "sec:")
    ("subsection" . "sec:")
    ("subsubsection" . "sec:"))
  "Default prefix when asking for a label.

Some LaTeX packages \(such as `fancyref'\) look at the prefix to generate some
text around cross-references automatically.  When using those packages, you
should not change this variable.

If it is a string, it it used unchanged for all kinds of sections.
If it is nil, no label is inserted.
If it is a list, the list is searched for a member whose car is equal
to the name of the sectioning command being inserted.  The cdr is then
used as the prefix.  If the name is not found, or if the cdr is nil,
no label is inserted."
  :group 'LaTeX-label
  :type '(choice (const :tag "none" nil)
                 (string :format "%v" :tag "Common")
                 (repeat :menu-tag "Level specific"
                         :format "\n%v%i"
                         (cons :format "%v"
                               (string :tag "Type")
                               (choice :tag "Prefix"
                                       (const :tag "none" nil)
                                       (string  :format "%v"))))))

;;; Section Hooks.

(defun LaTeX-section-heading ()
  "Hook to prompt for LaTeX section name.
Insert this hook into `LaTeX-section-hook' to allow the user to change
the name of the sectioning command inserted with \\[LaTeX-section]."
  (let ((string (completing-read
                 (format-prompt "Level" LaTeX-name)
                 (append
                  ;; Include starred variants in candidates.
                  (mapcar (lambda (sct)
                            (list (concat (car sct) "*")))
                          LaTeX-section-list)
                  LaTeX-section-list)
                 nil nil nil nil LaTeX-name)))
    ;; Update LaTeX-name
    (if (not (zerop (length string)))
        (setq LaTeX-name string))
    ;; Update level
    (setq LaTeX-level (LaTeX-section-level LaTeX-name))))

(defun LaTeX-section-title ()
  "Hook to prompt for LaTeX section title.
Insert this hook into `LaTeX-section-hook' to allow the user to change
the title of the section inserted with \\[LaTeX-section]."
  (setq LaTeX-title (TeX-read-string "Title: " LaTeX-title))
  (let ((region (and (TeX-active-mark)
                     (cons (region-beginning) (region-end)))))
    (when region (delete-region (car region) (cdr region)))))

(defun LaTeX-section-toc ()
  "Hook to prompt for the LaTeX section entry in the table of contents.
Insert this hook into `LaTeX-section-hook' to allow the user to insert
a different entry for the section in the table of contents."
  (setq LaTeX-toc (TeX-read-string "Toc Entry: "))
  (if (zerop (length LaTeX-toc))
      (setq LaTeX-toc nil)))

(defun LaTeX-section-section ()
  "Hook to insert LaTeX section command into the file.
Insert this hook into `LaTeX-section-hook' after those hooks that
set the `LaTeX-name', `LaTeX-title', and `LaTeX-toc' variables,
but before those hooks that assume that the section is already
inserted."
  ;; insert a new line if the current line and the previous line are
  ;; not empty (except for whitespace), with one exception: do not
  ;; insert a new line if the previous (or current, sigh) line starts
  ;; an environment (i.e., starts with `[optional whitespace]\begin')
  (unless (save-excursion
            (re-search-backward
             (concat "^\\s-*\n\\s-*\\=\\|^\\s-*" (regexp-quote TeX-esc)
                     "begin")
             (line-beginning-position 0) t))
    (LaTeX-newline))
  (insert TeX-esc LaTeX-name)
  (cond ((null LaTeX-toc))
        ((zerop (length LaTeX-toc))
         (insert LaTeX-optop)
         (set-marker LaTeX-done-mark (point))
         (insert LaTeX-optcl))
        (t
         (insert LaTeX-optop LaTeX-toc LaTeX-optcl)))
  (insert TeX-grop)
  (if (zerop (length LaTeX-title))
      (set-marker LaTeX-done-mark (point)))
  (insert LaTeX-title TeX-grcl)
  (LaTeX-newline)
  ;; If RefTeX is available, tell it that we've just made a new section
  (and (fboundp 'reftex-notice-new-section)
       (reftex-notice-new-section)))

(defun LaTeX-section-label ()
  "Hook to insert a label after the sectioning command.
Insert this hook into `LaTeX-section-hook' to prompt for a label to be
inserted after the sectioning command.

The behaviour of this hook is controlled by variable `LaTeX-section-label'."
  (and (LaTeX-label LaTeX-name 'section)
       (LaTeX-newline)))

;;; Environments

(defgroup LaTeX-environment nil
  "Environments in AUCTeX."
  :group 'LaTeX-macro)

(defcustom LaTeX-default-environment "itemize"
  "The default environment when creating new ones with `LaTeX-environment'.
It is overridden by `LaTeX-default-document-environment' when it
is non-nil and the current environment is \"document\"."
  :group 'LaTeX-environment
  :type 'string
  :local t)

(defvar-local LaTeX-default-document-environment nil
  "The default environment when creating new ones with
`LaTeX-environment' and the current one is \"document\".  This
variable overrides `LaTeX-default-environment'.")

(defvar-local LaTeX-default-tabular-environment "tabular"
  "The default tabular-like environment used when inserting a table env.
Styles such as tabularx may set it according to their needs.")

(defvar LaTeX-environment-history nil)

;; Variable used to cache the current environment, e.g. for repeated
;; tasks in an environment, like indenting each line in a paragraph to
;; be filled.  It must not have a non-nil value in general.  That
;; means it is usually let-bound for such operations.
(defvar LaTeX-current-environment nil)

(defun LaTeX-environment (arg)
  "Make LaTeX environment (\\begin{...}-\\end{...} pair).
With prefix ARG, modify current environment.

It may be customized with the following variables:

`LaTeX-default-environment'       Your favorite environment.
`LaTeX-default-style'             Your favorite document class.
`LaTeX-default-options'           Your favorite document class options.
`LaTeX-float'                     Where you want figures and tables to float.
`LaTeX-table-label'               Your prefix to labels in tables.
`LaTeX-figure-label'              Your prefix to labels in figures.
`LaTeX-default-format'            Format for array and tabular.
`LaTeX-default-width'             Width for minipage and tabular*.
`LaTeX-default-position'          Position for array and tabular."

  (interactive "*P")
  (let* ((default (cond
                   ((TeX-near-bobp) "document")
                   ((and LaTeX-default-document-environment
                         (string-equal (LaTeX-current-environment) "document"))
                    LaTeX-default-document-environment)
                   (t LaTeX-default-environment)))
         (environment (completing-read (format-prompt "Environment type" default)
                                       (LaTeX-environment-list-filtered) nil nil
                                       nil 'LaTeX-environment-history default)))
    ;; Use `environment' as default for the next time only if it is different
    ;; from the current default.
    (unless (equal environment default)
      (setq LaTeX-default-environment environment))

    (let ((entry (assoc environment (LaTeX-environment-list))))
      (if (null entry)
          (LaTeX-add-environments (list environment)))

      (if arg
          (LaTeX-modify-environment environment)
        (LaTeX-environment-menu environment)))))

(defun LaTeX-environment-menu (environment)
  "Insert ENVIRONMENT around point or region."
  (let ((entry (assoc environment (LaTeX-environment-list))))
    (cond ((not (and entry (nth 1 entry)))
           (LaTeX-insert-environment environment))
          ((numberp (nth 1 entry))
           (let ((count (nth 1 entry))
                 (args ""))
             (while (> count 0)
               (setq args (concat args TeX-grop TeX-grcl))
               (setq count (- count 1)))
             (LaTeX-insert-environment environment args)))
          ((or (stringp (nth 1 entry)) (vectorp (nth 1 entry)))
           (let ((prompts (cdr entry))
                 (args ""))
             (dolist (elt prompts)
               (let* ((optional (vectorp elt))
                      (elt (if optional (elt elt 0) elt))
                      (arg (TeX-read-string
                            (TeX-argument-prompt optional elt nil))))
                 (setq args (concat args
                                    (cond ((and optional (> (length arg) 0))
                                           (concat LaTeX-optop arg LaTeX-optcl))
                                          ((not optional)
                                           (concat TeX-grop arg TeX-grcl)))))))
             (LaTeX-insert-environment environment args)))
          (t
           (apply (nth 1 entry) environment (nthcdr 2 entry))))))

(defun LaTeX-close-environment (&optional reopen)
  "Create an \\end{...} to match the current environment.
With prefix argument REOPEN, reopen environment afterwards."
  (interactive "*P")
  (if (> (point)
         (save-excursion
           (beginning-of-line)
           (when LaTeX-insert-into-comments
             (if (looking-at comment-start-skip)
                 (goto-char (match-end 0))))
           (skip-chars-forward " \t")
           (point)))
      (LaTeX-newline))
  (let ((environment (LaTeX-current-environment 1)) marker)
    (insert "\\end{" environment "}")
    (indent-according-to-mode)
    (if (or (not (looking-at "[ \t]*$"))
            (and (TeX-in-commented-line)
                 (save-excursion (beginning-of-line 2)
                                 (not (TeX-in-commented-line)))))
        (LaTeX-newline)
      (unless (= (forward-line 1) 0)
        (insert "\n")))
    (indent-according-to-mode)
    (when reopen
      (save-excursion
        (setq marker (point-marker))
        (set-marker-insertion-type marker t)
        (LaTeX-environment-menu environment)
        (delete-region (point)
                       (if (save-excursion (goto-char marker)
                                           (bolp))
                           (1- marker)
                         marker))
        (move-marker marker nil)))))

(define-obsolete-variable-alias 'LaTeX-after-insert-env-hooks 'LaTeX-after-insert-env-hook "11.89")

(defvar LaTeX-indent-environment-list) ;; Defined further below.

(defvar LaTeX-after-insert-env-hook nil
  "List of functions to be run at the end of `LaTeX-insert-environment'.
Each function is called with three arguments: the name of the
environment just inserted, the buffer position just before
\\begin and the position just before \\end.")

(defun LaTeX-insert-environment (environment &optional extra)
  "Insert LaTeX ENVIRONMENT with optional argument EXTRA."
  (let ((active-mark (and (TeX-active-mark) (not (eq (mark) (point)))))
        prefix content-start env-start env-end additional-indent)
    (when (and active-mark (< (mark) (point))) (exchange-point-and-mark))
    ;; Compute the prefix.
    (when (and LaTeX-insert-into-comments (TeX-in-commented-line))
      (save-excursion
        (beginning-of-line)
        (looking-at
         (concat "^\\([ \t]*" TeX-comment-start-regexp "+\\)+[ \t]*"))
        (setq prefix (match-string 0))))
    ;; What to do with the line containing point.
    ;; - Open a new empty line for later insertion of "\begin{foo}" and
    ;;   put the point there.
    ;; - If there were at first any non-whitespace texts between the
    ;;   point and EOL, send them into their new own line with possible
    ;;   comment prefix.
    (cond (;; When the entire line consists of whitespaces except
           ;; possible prefix...
           (save-excursion (beginning-of-line)
                           (looking-at (concat prefix "[ \t]*$")))
           ;; ...make the line empty and put the point there.
           (delete-region (match-beginning 0) (match-end 0)))
          (;; When there are only whitespaces except possible prefix
           ;; between the point and BOL (including the case the point
           ;; is at BOL)...
           (TeX-looking-at-backward (if prefix
                                        (concat "^\\(" prefix "\\)?[ \t]*")
                                      "^[ \t]*")
                                    (line-beginning-position))
           ;; ...in this case, we have non-whitespace texts between
           ;; the point and EOL, so send the entire line into a new
           ;; next line and put the point on the empty line just
           ;; created.
           (beginning-of-line)
           (newline)
           (beginning-of-line 0)
           ;; Take note that there are texts to be indented later
           ;; unless the region is activated.
           (unless active-mark
             (setq additional-indent t)))
          (;; In all other cases...
           t
           ;; ...insert a new empty line after deleting all
           ;; whitespaces around the point, put the point there...
           (delete-horizontal-space)
           (if (eolp)
               (newline)
             ;; ...and if there were at first any non-whitespace texts
             ;; between (the original position of) the point and EOL,
             ;; send them into a new next line with possible comment
             ;; prefix.
             (newline 2)
             (when prefix (insert prefix))
             (beginning-of-line 0)
             ;; Take note that there are texts to be indented later
             ;; unless the region is activated.
             (unless active-mark
               (setq additional-indent t)))))
    ;; What to do with the line containing mark.
    ;; If there is active region...
    (when active-mark
      ;; - Open a new empty line for later insertion of "\end{foo}"
      ;;   and put the mark there.
      ;; - If there were at first any non-whitespace texts between the
      ;;   mark and EOL, pass them over the empty line and put them on
      ;;   their own line with possible comment prefix.
      (save-excursion
        (goto-char (mark))
        (cond (;; When the entire line consists of whitespaces except
               ;; possible prefix...
               (save-excursion (beginning-of-line)
                               (looking-at
                                (if prefix
                                    (concat "\\(" prefix "\\)?[ \t]*$")
                                  "[ \t]*$")))
               ;; ...make the line empty and put the mark there.
               (delete-region (match-beginning 0) (match-end 0)))
              (;; When there are only whitespaces except possible prefix
               ;; between the mark and BOL (including the case the mark
               ;; is at BOL)...
               (TeX-looking-at-backward (if prefix
                                            (concat "^\\(" prefix "\\)?[ \t]*")
                                          "^[ \t]*")
                                        (line-beginning-position))
               ;; ...in this case, we have non-whitespace texts
               ;; between the mark and EOL, so send the entire line
               ;; into a new next line and put the mark on the empty
               ;; line just created.
               (beginning-of-line)
               (set-mark (point))
               (newline)
               ;; Take note that there are texts to be indented later.
               (setq additional-indent t))
              (;; In all other cases...
               t
               ;; ...make a new empty line after deleting all
               ;; whitespaces around the mark, put the mark there...
               (delete-horizontal-space)
               (insert-before-markers "\n")
               ;; ...and if there were at first any non-whitespace
               ;; texts between (the original position of) the mark
               ;; and EOL, send them into a new next line with
               ;; possible comment prefix.
               (unless (eolp)
                 (newline)
                 (when prefix (insert prefix))
                 ;; Take note that there are texts to be indented
                 ;; later.
                 (setq additional-indent t))))))
    ;; Now insert the environment.
    (when prefix (insert prefix))
    (setq env-start (point))
    (insert TeX-esc "begin" TeX-grop environment TeX-grcl)
    (indent-according-to-mode)
    (when extra (insert extra))
    (setq content-start (line-beginning-position 2))
    (unless active-mark
      (newline)
      (when prefix (insert prefix))
      (newline))
    (when active-mark (goto-char (mark)))
    (when prefix (insert prefix))
    (insert TeX-esc "end" TeX-grop environment TeX-grcl)
    (end-of-line 0)
    (if active-mark
        (progn
          (if (and auto-fill-function
                   (not (assoc environment LaTeX-indent-environment-list)))
              ;; Fill the region only when `auto-fill-mode' is active
              ;; and no special indent rule exists.
              (LaTeX-fill-region content-start (line-beginning-position 2))
            ;; Else just indent the region. (bug#48518, bug#28382)
            (indent-region content-start (line-beginning-position 2)))
          (set-mark content-start))
      (indent-according-to-mode))
    ;; Indent \end{foo}.
    (save-excursion (beginning-of-line 2) (indent-according-to-mode)
                    (when additional-indent
                      ;; Indent texts sent after the inserted
                      ;; environment.
                      (forward-line 1) (indent-according-to-mode)))
    (TeX-math-input-method-off)
    (setq env-end (save-excursion
                    (search-forward
                     (concat TeX-esc "end" TeX-grop
                             environment TeX-grcl))
                    (match-beginning 0)))
    (run-hook-with-args 'LaTeX-after-insert-env-hook
                        environment env-start env-end)))

(defun LaTeX-environment-name-regexp ()
  "Return the regexp matching the name of a LaTeX environment.
This matches everything different from a TeX closing brace but
allowing one level of TeX group braces."
  (concat "\\([^" TeX-grcl TeX-grop "]*\\(" (regexp-quote TeX-grop)
          "[^" TeX-grcl TeX-grop "]*" (regexp-quote TeX-grcl) "\\)*[^"
          TeX-grcl TeX-grop "]*\\)"))

(defvar LaTeX-after-modify-env-hook nil
  "List of functions to be run at the end of `LaTeX-modify-environment'.
Each function is called with four arguments: the new name of the
environment, the former name of the environment, the buffer
position just before \\begin and the position just before
\\end.")

(defun LaTeX-modify-environment (environment)
  "Modify current environment to new ENVIRONMENT."
  (let ((goto-end (lambda ()
                    (LaTeX-find-matching-end)
                    (re-search-backward (concat (regexp-quote TeX-esc)
                                                "end"
                                                (regexp-quote TeX-grop)
                                                (LaTeX-environment-name-regexp)
                                                (regexp-quote TeX-grcl))
                                        (line-beginning-position))))
        (goto-begin (lambda ()
                      (LaTeX-find-matching-begin)
                      (prog1 (point)
                        (re-search-forward (concat (regexp-quote TeX-esc)
                                                   "begin"
                                                   (regexp-quote TeX-grop)
                                                   (LaTeX-environment-name-regexp)
                                                   (regexp-quote TeX-grcl))
                                           (line-end-position))))))
    (save-excursion
      (funcall goto-end)
      (let ((old-env (match-string-no-properties 1))
            beg-pos)
        (replace-match environment t t nil 1)
        ;; This failed when \begin and \end lie on the same line. (bug#58689)
        ;; (beginning-of-line 1)
        (setq beg-pos (funcall goto-begin))
        (replace-match environment t t nil 1)
        ;; (end-of-line 1)
        (run-hook-with-args 'LaTeX-after-modify-env-hook
                            environment old-env
                            beg-pos
                            (funcall goto-end))))))

(defvar LaTeX-syntactic-comments) ;; Defined further below.

(defun LaTeX-current-environment (&optional arg)
  "Return the name (a string) of the enclosing LaTeX environment.
With optional ARG>=1, find that outer level.

If function is called inside a comment and
`LaTeX-syntactic-comments' is enabled, try to find the
environment in commented regions with the same comment prefix.

The functions `LaTeX-find-matching-begin' and `LaTeX-find-matching-end'
work analogously."
  (save-excursion
    (if (LaTeX-backward-up-environment arg)
        (progn
          (re-search-forward (concat
                              TeX-grop (LaTeX-environment-name-regexp)
                              TeX-grcl))
          (match-string-no-properties 1))
      "document")))

(defun LaTeX-backward-up-environment (&optional arg)
  "Move backward out of the enclosing environment.
Helper function of `LaTeX-current-environment' and
`LaTeX-find-matching-begin'.
With optional ARG>=1, find that outer level.
Return non-nil if the operation succeeded.

Assume the current point is on neither \"begin{foo}\" nor \"end{foo}\"."
  (setq arg (if arg (if (< arg 1) 1 arg) 1))
  (let* ((in-comment (TeX-in-commented-line))
         (comment-prefix (and in-comment (TeX-comment-prefix)))
         (case-fold-search nil))
    (while (and (/= arg 0)
                (re-search-backward
                 (concat (regexp-quote TeX-esc) "\\(begin\\|end\\)\\b") nil t))
      (when (or (and LaTeX-syntactic-comments
                     (eq in-comment (TeX-in-commented-line))
                     (or (not in-comment)
                         ;; Consider only matching prefixes in the
                         ;; commented case.
                         (string= comment-prefix (TeX-comment-prefix))))
                (and (not LaTeX-syntactic-comments)
                     (not (TeX-in-commented-line)))
                ;; macrocode*? in docTeX-mode is special since we have
                ;; also regular code lines not starting with a
                ;; comment-prefix.  Hence, the next check just looks
                ;; if we're inside such a group and returns non-nil to
                ;; recognize such a situation.
                (and (eq major-mode 'docTeX-mode)
                     (looking-at-p (concat (regexp-quote TeX-esc)
                                   "\\(?:begin\\|end\\) *{macrocode\\*?}"))))
        (setq arg (if (= (char-after (match-beginning 1)) ?e)
                      (1+ arg)
                    (1- arg)))))
    (= arg 0)))

(defun docTeX-in-macrocode-p ()
  "Determine if point is inside a macrocode environment."
  (let ((case-fold-search nil))
    (save-excursion
      (re-search-backward
       (concat "^%    " (regexp-quote TeX-esc)
               "\\(begin\\|end\\)[ \t]*{macrocode\\*?}") nil 'move)
      (not (or (bobp)
               (= (char-after (match-beginning 1)) ?e))))))


;;; Environment Hooks

(defvar LaTeX-document-style-hook nil
  "List of hooks to run when inserting a document environment.

To insert a hook here, you must insert it in the appropriate style file.")

(defun LaTeX-env-document (&optional _ignore)
  "Create new LaTeX document.
Also inserts a \\documentclass macro if there's none already and
prompts for the insertion of \\usepackage macros.

The compatibility argument IGNORE is ignored."
  ;; just assume a single valid \\documentclass, i.e., one not in a
  ;; commented line
  (let ((found nil))
    (save-excursion
      (while (and (not found)
                  (re-search-backward
                   "\\\\documentclass\\(\\[[^]\n\r]*\\]\\)?\\({[^}]+}\\)"
                   nil t))
        (and (not (TeX-in-commented-line))
             (setq found t))))
    (when (not found)
      (TeX-insert-macro "documentclass")
      (LaTeX-newline)
      (LaTeX-newline)
      ;; Add a newline only if some `\usepackage' has been inserted.
      (if (LaTeX-insert-usepackages)
          (LaTeX-newline))
      (LaTeX-newline)
      (end-of-line 0)))
  (LaTeX-insert-environment "document")
  (run-hooks 'LaTeX-document-style-hook)
  (setq LaTeX-document-style-hook nil))

(defcustom LaTeX-float ""
  "Default float position for figures and tables.
If nil, act like the empty string is given, but do not prompt.
\(The standard LaTeX classes use [tbp] as float position if the
optional argument is omitted.)"
  :group 'LaTeX-environment
  :type '(choice (const :tag "Do not prompt" nil)
                 (const :tag "Empty" "")
                 (string :format "%v"))
  :local t)

(defcustom LaTeX-top-caption-list nil
  "List of float environments with top caption."
  :group 'LaTeX-environment
  :type '(repeat (string :format "%v")))

(defgroup LaTeX-label nil
  "Adding labels for LaTeX commands in AUCTeX."
  :group 'LaTeX)

(defcustom LaTeX-label-function #'LaTeX-label--default
  "A function inserting a label at point or returning a label string.
Called with two argument NAME and NO-INSERT where NAME is the environment.
The function has to return the label inserted, or nil if no label was
inserted.  If the optional argument NO-INSERT is non-nil, then
the function has to return the label as string without any
insertion or nil if no label was read in."
  :group 'LaTeX-label
  :type 'function)

(defcustom LaTeX-figure-label "fig:"
  "Default prefix to figure labels."
  :group 'LaTeX-label
  :group 'LaTeX-environment
  :type 'string)

(defcustom LaTeX-table-label "tab:"
  "Default prefix to table labels."
  :group 'LaTeX-label
  :group 'LaTeX-environment
  :type 'string)

(defcustom LaTeX-listing-label "lst:"
  "Default prefix to listing labels.
This prefix should apply to all environments which typeset
code listings and take a caption and label."
  :group 'LaTeX-label
  :group 'LaTeX-environment
  :type 'string)

(defcustom LaTeX-default-format ""
  "Default format for array and tabular environments."
  :group 'LaTeX-environment
  :type 'string
  :local t)

(defcustom LaTeX-default-width "1.0\\linewidth"
  "Default width for minipage and tabular* environments."
  :group 'LaTeX-environment
  :type 'string
  :local t)

(defcustom LaTeX-default-position ""
  "Default position for array and tabular environments.
If nil, act like the empty string is given, but do not prompt."
  :group 'LaTeX-environment
  :type '(choice (const :tag "Do not prompt" nil)
                 (const :tag "Empty" "")
                 string)
  :local t)

(defcustom LaTeX-equation-label "eq:"
  "Default prefix to equation labels."
  :group 'LaTeX-label
  :type 'string)

(defcustom LaTeX-eqnarray-label LaTeX-equation-label
  "Default prefix to eqnarray labels."
  :group 'LaTeX-label
  :type 'string)

(defun LaTeX--env-parse-args (args)
  "Helper function to insert arguments defined by ARGS.
This function checks if `TeX-exit-mark' is set, otherwise it's
set to the point where this function starts.  Point will be at
`TeX-exit-mark' when this function exits."
  (let ((TeX-exit-mark (or TeX-exit-mark
                           (point-marker))))
    (LaTeX-find-matching-begin)
    (end-of-line)
    (TeX-parse-arguments args)
    (goto-char TeX-exit-mark)
    (set-marker TeX-exit-mark nil)))

(defun LaTeX--env-item (environment)
  "Helper function running inside `LaTeX-env-item'.
The body of this function used to be part of `LaTeX-env-item'."
  (if (TeX-active-mark)
      (progn
        (LaTeX-find-matching-begin)
        (end-of-line 1))
    (end-of-line 0))
  (delete-char 1)
  (when (looking-at (concat "^[ \t]+$\\|"
                            "^[ \t]*" TeX-comment-start-regexp "+[ \t]*$"))
    (delete-region (point) (line-end-position)))
  (delete-horizontal-space)
  ;; Deactivate the mark here in order to prevent `TeX-parse-macro'
  ;; from swapping point and mark and the \item ending up right after
  ;; \begin{...}.
  (deactivate-mark)
  (LaTeX-insert-item)
  ;; The inserted \item may have outdented the first line to the
  ;; right.  Fill it, if appropriate and `auto-fill-mode' is active.
  (when (and auto-fill-function
             (not (looking-at "$"))
             (not (assoc environment LaTeX-indent-environment-list))
             (> (- (line-end-position) (line-beginning-position))
                (current-fill-column)))
    (LaTeX-fill-paragraph nil)))

(defun LaTeX-env-item (environment)
  "Insert ENVIRONMENT and the first item.
The first item is inserted by the function `LaTeX--env-item'."
  (LaTeX-insert-environment environment)
  (LaTeX--env-item environment))

(defun LaTeX-env-item-args (environment &rest args)
  "Insert ENVIRONMENT followed by ARGS and first item.
The first item is inserted by the function `LaTeX--env-item'."
  (LaTeX-insert-environment environment)
  (LaTeX--env-parse-args args)
  (LaTeX--env-item environment))

(defcustom LaTeX-label-alist
  '(("figure" . LaTeX-figure-label)
    ("table" . LaTeX-table-label)
    ("figure*" . LaTeX-figure-label)
    ("table*" . LaTeX-table-label)
    ("equation" . LaTeX-equation-label)
    ("eqnarray" . LaTeX-eqnarray-label))
  "Lookup prefixes for labels.
An alist where the CAR is the environment name, and the CDR
either the prefix or a symbol referring to one.

If the name is not found, or if the CDR is nil, no label is
automatically inserted for that environment.

If you want to automatically insert a label for a environment but
with an empty prefix, use the empty string \"\" as the CDR of the
corresponding entry."
  :group 'LaTeX-label
  :type '(repeat (cons (string :tag "Environment")
                       (choice (string :tag "Label prefix")
                               (symbol :tag "Label prefix symbol"))))
  :local t)

(defvar TeX-read-label-prefix nil
  "Initial input for the label in `TeX-read-label'.")

(defun LaTeX-label (name &optional type no-insert)
  "Insert a label for NAME at point.
The optional TYPE argument can be either environment or section:
in the former case this function looks up `LaTeX-label-alist' to
choose which prefix to use for the label, in the latter case
`LaTeX-section-label' will be looked up instead.  If TYPE is nil,
you will be always prompted for a label, with an empty default
prefix.

If `LaTeX-label-function' is a valid function, LaTeX label will
transfer the job to this function.

If the optional NO-INSERT is non-nil, only the label is returned
and no insertion happens.  Otherwise the inserted label is
returned, nil if it is empty."
  (let ((TeX-read-label-prefix
         (cond
          ((eq type 'environment)
           (cdr (assoc name LaTeX-label-alist)))
          ((eq type 'section)
           (if (assoc name LaTeX-section-list)
               (if (stringp LaTeX-section-label)
                   LaTeX-section-label
                 (and (listp LaTeX-section-label)
                      (cdr (assoc name LaTeX-section-label))))
             ""))
          ((null type)
           "")
          (t
           nil)))
        ) ;; label
    (when (symbolp TeX-read-label-prefix)
      (setq TeX-read-label-prefix (symbol-value TeX-read-label-prefix)))
    (when TeX-read-label-prefix
      (funcall (or LaTeX-label-function #'LaTeX-label--default)
               name no-insert))))

(defun LaTeX-label--default (_name no-insert)
  ;; Use completing-read as we do with `C-c C-m \label RET'
  (let ((label (TeX-read-label t "What label" t)))
    ;; No label or empty string entered?
    (if (or (string= TeX-read-label-prefix label)
            (string= "" label))
        (setq label nil)
      ;; We have a label; when NO-INSERT is nil, insert
      ;; \label{label} in the buffer, add new label to list of
      ;; known labels and return it
      (unless no-insert
        (insert TeX-esc "label" TeX-grop label TeX-grcl))
      (LaTeX-add-labels label)
      label)))

(defcustom LaTeX-short-caption-prompt-length 40
  "The length that the caption of a figure should be before
propting for \\caption's optional short-version."
  :group 'LaTeX-environment
  :type 'integer)

(defun LaTeX-compose-caption-macro (caption &optional short-caption)
  "Return a \\caption macro for a given CAPTION as a string.
If SHORT-CAPTION is non-nil pass it as an optional argument to
\\caption."
  (let ((short-caption-string
         (if (and short-caption
                  (not (string= short-caption "")))
             (concat LaTeX-optop short-caption LaTeX-optcl))))
    (concat TeX-esc "caption" short-caption-string
            TeX-grop caption TeX-grcl)))

(defun LaTeX-env-figure (environment)
  "Create ENVIRONMENT with \\caption and \\label commands."
  (let* ((float (and LaTeX-float                ; LaTeX-float can be nil, i.e.
                                        ; do not prompt
                     (TeX-read-string "(Optional) Float position: " LaTeX-float)))
         (caption (TeX-read-string "Caption: "))
         (short-caption (when (>= (length caption) LaTeX-short-caption-prompt-length)
                          (TeX-read-string "(Optional) Short caption: ")))
         (center (y-or-n-p "Center? "))
         (active-mark (and (TeX-active-mark)
                           (not (eq (mark) (point)))))
         start-marker end-marker)
    (when active-mark
      (if (< (mark) (point))
          (exchange-point-and-mark))
      (setq start-marker (point-marker))
      (set-marker-insertion-type start-marker t)
      (setq end-marker (copy-marker (mark))))
    (setq LaTeX-float float)
    (LaTeX-insert-environment environment
                              (unless (zerop (length float))
                                (concat LaTeX-optop float
                                        LaTeX-optcl)))
    (when active-mark
      (goto-char start-marker)
      (set-marker start-marker nil))
    (when center
      (insert TeX-esc "centering")
      (indent-according-to-mode)
      (LaTeX-newline)
      (indent-according-to-mode))
    ;; Insert caption and ask for a label, do nothing if user skips caption
    (unless (zerop (length caption))
      (if (member environment LaTeX-top-caption-list)
          ;; top caption
          (progn
            (insert (LaTeX-compose-caption-macro caption short-caption))
            ;; If `auto-fill-mode' is active, fill the caption.
            (if auto-fill-function (LaTeX-fill-paragraph))
            (LaTeX-newline)
            (indent-according-to-mode)
            ;; ask for a label and insert a new line only if a label is
            ;; actually inserted
            (when (LaTeX-label environment 'environment)
              (LaTeX-newline)
              (indent-according-to-mode)))
        ;; bottom caption (default)
        (when active-mark (goto-char end-marker))
        (save-excursion
          (LaTeX-newline)
          (indent-according-to-mode)
          ;; If there is an active region point is before the backslash of
          ;; "\end" macro, go one line upwards.
          (when active-mark (forward-line -1) (indent-according-to-mode))
          (insert (LaTeX-compose-caption-macro caption short-caption))
          ;; If `auto-fill-mode' is active, fill the caption.
          (if auto-fill-function (LaTeX-fill-paragraph))
          ;; ask for a label and if necessary insert a new line between caption
          ;; and label
          (when (save-excursion (LaTeX-label environment 'environment))
            (LaTeX-newline)
            (indent-according-to-mode)))
        ;; Insert an empty line between caption and marked region, if any.
        (when active-mark (LaTeX-newline) (forward-line -1))
        (indent-according-to-mode)))
    (when (markerp end-marker)
      (set-marker end-marker nil))
    (when (and (member environment '("table" "table*"))
               ;; Suppose an existing tabular environment should just
               ;; be wrapped into a table if there is an active region.
               (not active-mark))
      (LaTeX-environment-menu LaTeX-default-tabular-environment))))

(defun LaTeX-env-array (environment)
  "Insert ENVIRONMENT with position and column specifications.
Just like array and tabular."
  (let ((pos (and LaTeX-default-position ; LaTeX-default-position can
                                        ; be nil, i.e. do not prompt
                  (TeX-read-string "(Optional) Position: " LaTeX-default-position)))
        (fmt (TeX-read-string
              (format-prompt "Format" LaTeX-default-format)
              nil nil
              (if (string= LaTeX-default-format "")
                  nil
                LaTeX-default-format))))
    (setq LaTeX-default-position pos)
    (setq LaTeX-default-format fmt)
    (LaTeX-insert-environment environment
                              (concat
                               (unless (zerop (length pos))
                                 (concat LaTeX-optop pos LaTeX-optcl))
                               (concat TeX-grop fmt TeX-grcl)))
    (LaTeX-item-array t)))

(defun LaTeX-env-label (environment)
  "Insert ENVIRONMENT and prompt for label."
  (LaTeX-insert-environment environment)
  (when (TeX-active-mark)
    ;; Point is at the end of the region.  Move it back to the
    ;; beginning of the region.
    (exchange-point-and-mark)
    (indent-according-to-mode))
  (when (LaTeX-label environment 'environment)
    (LaTeX-newline)
    (indent-according-to-mode))
  (when (TeX-active-mark)
    ;; Restore the positions of point and mark.
    (exchange-point-and-mark)))

(defun LaTeX-env-label-args (environment &rest args)
  "Run `LaTeX-env-label' on ENVIRONMENT and insert ARGS."
  (LaTeX-env-label environment)
  (LaTeX--env-parse-args args))

(defun LaTeX-env-list (environment)
  "Insert ENVIRONMENT and the first item."
  (let ((label (TeX-read-string "Default Label: ")))
    (LaTeX-insert-environment environment
                              (format "{%s}{}" label))
    (end-of-line 0)
    (delete-char 1)
    (delete-horizontal-space))
  (LaTeX-insert-item))

(defun LaTeX-env-minipage (environment)
  "Create new LaTeX minipage or minipage-like ENVIRONMENT."
  (let* ((pos (and LaTeX-default-position ; LaTeX-default-position can
                                        ; be nil, i.e. do not prompt
                   (completing-read
                    (TeX-argument-prompt t nil "Position")
                    '("t" "b" "c"))))
         (height (when (and pos (not (string= pos "")))
                   (completing-read (TeX-argument-prompt t nil "Height")
                                    ;; A valid length can be a macro
                                    ;; or a length of the form
                                    ;; <value><dimension>.  Input
                                    ;; starting with a `\' can be
                                    ;; completed with length macros.
                                    (mapcar (lambda (elt)
                                              (concat TeX-esc (car elt)))
                                            (LaTeX-length-list)))))
         (inner-pos (when (and height (not (string= height "")))
                      (completing-read
                       (TeX-argument-prompt t nil "Inner position")
                       '("t" "b" "c" "s"))))
         (width (TeX-read-string
                 (format-prompt "Width" LaTeX-default-width)
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

(defun LaTeX-env-tabular* (environment)
  "Insert ENVIRONMENT with width, position and column specifications."
  (let ((width (TeX-read-string
                (format-prompt "Width" LaTeX-default-width)
                nil nil LaTeX-default-width))
        (pos (and LaTeX-default-position ; LaTeX-default-position can
                                        ; be nil, i.e. do not prompt
                  (TeX-read-string "(Optional) Position: " LaTeX-default-position)))
        (fmt (TeX-read-string
              (format-prompt "Format" LaTeX-default-format)
              nil nil
              (if (string= LaTeX-default-format "")
                  nil
                LaTeX-default-format))))
    (setq LaTeX-default-width width)
    (setq LaTeX-default-position pos)
    (setq LaTeX-default-format fmt)
    (LaTeX-insert-environment environment
                              (concat
                               (concat TeX-grop width TeX-grcl) ;; not optional!
                               (unless (zerop (length pos))
                                 (concat LaTeX-optop pos LaTeX-optcl))
                               (concat TeX-grop fmt TeX-grcl)))
    (LaTeX-item-tabular* t)))

(defun LaTeX-env-picture (environment)
  "Insert ENVIRONMENT with width, height specifications."
  (let ((width (TeX-read-string "Width: "))
        (height (TeX-read-string "Height: "))
        (x-offset (TeX-read-string "X Offset: "))
        (y-offset (TeX-read-string "Y Offset: ")))
    (if (zerop (length x-offset))
        (setq x-offset "0"))
    (if (zerop (length y-offset))
        (setq y-offset "0"))
    (LaTeX-insert-environment environment
                              (concat
                               (format "(%s,%s)" width height)
                               (if (not (and (string= x-offset "0")
                                             (string= y-offset "0")))
                                   (format "(%s,%s)" x-offset y-offset))))))

(defun LaTeX-env-bib (environment)
  "Insert ENVIRONMENT with label for bibitem."
  (LaTeX-insert-environment environment
                            (concat TeX-grop
                                    (TeX-read-string
                                     (format-prompt "Label for BibItem" "99")
                                     nil nil "99")
                                    TeX-grcl))
  (end-of-line 0)
  (delete-char 1)
  (delete-horizontal-space)
  (LaTeX-insert-item))

(defun LaTeX-env-args (environment &rest args)
  "Insert ENVIRONMENT and arguments defined by ARGS."
  (LaTeX-insert-environment environment)
  (LaTeX--env-parse-args args))

(defun LaTeX-env-label-as-keyval (_optional &optional keyword keyvals environment)
  "Query for a label and insert it in the optional argument of an environment.
OPTIONAL is ignored.  Optional KEYWORD is a string to search for
in the optional argument, label is only included if KEYWORD is
found.  KEYVALS is a string with key=val's read in.  If nil, this
function searchs for key=val's itself.  ENVIRONMENT is a string
with the name of environment, if non-nil, don't bother to find
out."
  (let ((env-start (make-marker))
        (body-start (make-marker))
        (opt-start (make-marker))
        (opt-end   (make-marker))
        (currenv (or environment (LaTeX-current-environment))))
    ;; Save the starting point as we will come back here
    (set-marker body-start (point))
    ;; Go to the start of the current environment and save the position
    (LaTeX-find-matching-begin)
    (set-marker env-start (point))
    ;; Check if an opt. argument is there; assume that it starts in
    ;; the same line and save the points in markers
    (when (re-search-forward
           (concat "\\\\begin{" currenv "}[ \t]*\\[") body-start t)
      (set-marker opt-start (1- (point)))
      (goto-char opt-start)
      (forward-sexp)
      (set-marker opt-end (1- (point))))
    ;; If keyword argument is given and keyvals argument is not given,
    ;; parse the optional argument and put it into keyvals
    (when (and keyword
               (marker-position opt-start)
               (not keyvals))
      (setq keyvals (buffer-substring-no-properties
                     (1+ opt-start) opt-end)))
    ;; If keyword is given, only insert a label when keyword is found
    ;; inside the keyvals.  If keyword is nil, then insert a label
    ;; anyways
    (if (stringp keyword)
        (when (and (stringp keyvals)
                   (not (string= keyvals ""))
                   (string-match (concat keyword "[ \t]*=") keyvals))
          (goto-char opt-end)
          (let ((opt-label (LaTeX-label currenv 'environment t)))
            (when opt-label
              (insert (if (equal (preceding-char) ?,)
                          "label="
                        ",label=")
                      TeX-grop opt-label TeX-grcl))))
      (let ((opt-label (LaTeX-label currenv 'environment t)))
        (when opt-label
          ;; Check if an opt. argument is found and go to the end if
          (if (marker-position opt-end)
              (progn
                (goto-char opt-end)
                (insert (if (equal (preceding-char) ?,)
                            "label="
                          ",label=")
                        TeX-grop opt-label TeX-grcl))
            ;; Otherwise start at the beginning of environment in
            ;; order to not mess with any other mandatory arguments
            ;; which can be there
            (goto-char env-start)
            (re-search-forward (concat "\\\\begin{" currenv "}"))
            (insert LaTeX-optop "label=" TeX-grop opt-label TeX-grcl LaTeX-optcl)))))
    ;; Go to where we started and clean up the markers
    (goto-char body-start)
    (set-marker env-start nil)
    (set-marker body-start nil)
    (set-marker opt-start nil)
    (set-marker opt-end nil)))

;;; Item hooks

(defvar LaTeX-item-list nil
  "A list of environments where items have a special syntax.
The cdr is the name of the function, used to insert this kind of items.")

(defun LaTeX-insert-item ()
  "Insert a new item in an environment.
You may use `LaTeX-item-list' to change the routines used to insert the item."
  (interactive "*")
  (let ((environment (LaTeX-current-environment)))
    (when (and (TeX-active-mark)
               (> (point) (mark)))
      (exchange-point-and-mark))
    (if (save-excursion
          ;; If the current line has only whitespace characters, put
          ;; the new \item on this line, not creating a new line
          ;; below.
          (goto-char (line-beginning-position))
          (if LaTeX-insert-into-comments
              (re-search-forward
               (concat "\\=" TeX-comment-start-regexp "+")
               (line-end-position) t))
          (looking-at "[ \t]*$"))
        (delete-region (match-beginning 0) (match-end 0))
      (LaTeX-newline))
    (if (assoc environment LaTeX-item-list)
        (funcall (cdr (assoc environment LaTeX-item-list)))
      (TeX-insert-macro "item"))
    (indent-according-to-mode)))

(defvar TeX-arg-item-label-p) ;; Defined further below.

(defun LaTeX-item-argument ()
  "Insert a new item with an optional argument."
  (let ((TeX-arg-item-label-p t)
        (TeX-insert-macro-default-style 'show-optional-args))
    (TeX-insert-macro "item")))

(defun LaTeX-item-bib ()
  "Insert a new bibitem."
  (TeX-insert-macro "bibitem"))

(defvar LaTeX-array-skipping-regexp (regexp-opt '("[t]" "[b]" ""))
   "Regexp matching between \\begin{xxx} and column specification.
For array and tabular environments.  See `LaTeX-insert-ampersands' for
detail.")

(defvar LaTeX-tabular*-skipping-regexp
  ;; Assume width specification contains neither nested curly brace
  ;; pair nor escaped "}".
  (concat "{[^}]*}[ \t]*" (regexp-opt '("[t]" "[b]" "")))
   "Regexp matching between \\begin{tabular*} and column specification.
For tabular* environment only.  See `LaTeX-insert-ampersands' for detail.")

(defun LaTeX-item-array (&optional suppress)
  "Insert line break macro on the last line and suitable number of &'s.
For array and tabular environments.

If SUPPRESS is non-nil, do not insert line break macro."
  (unless suppress
    (save-excursion
      (end-of-line 0)
      (just-one-space)
      (TeX-insert-macro "\\")))
  (LaTeX-insert-ampersands
   LaTeX-array-skipping-regexp #'LaTeX-array-count-columns))

(defun LaTeX-item-tabular* (&optional suppress)
  "Insert line break macro on the last line and suitable number of &'s.
For tabular* environment only.

If SUPPRESS is non-nil, do not insert line break macro."
  (unless suppress
    (save-excursion
      (end-of-line 0)
      (just-one-space)
      (TeX-insert-macro "\\")))
  (LaTeX-insert-ampersands
   LaTeX-tabular*-skipping-regexp #'LaTeX-array-count-columns))

(defun LaTeX-insert-ampersands (regexp func)
  "Insert suitable number of ampersands for the current environment.
The number is calculated from REGEXP and FUNC.

Example 1:
Consider the case that the current environment begins with
\\begin{array}[t]{|lcr|}
.  REGEXP must be chosen to match \"[t]\", that is, the text between just
after \"\\begin{array}\" and just before \"{|lcr|}\", which encloses
the column specification.  FUNC must return the number of ampersands to
be inserted, which is 2 since this example specifies three columns.
FUNC is called with two arguments START and END, which spans the column
specification (without enclosing braces.)  REGEXP is used to determine
these START and END.

Example 2:
This time the environment begins with
\\begin{tabular*}{1.0\\linewidth}[b]{c@{,}p{5ex}}
.  REGEXP must match \"{1.0\\linewidth}[b]\" and FUNC must return 1 from
the text \"c@{,}p{5ex}\" between START and END specified two columns.

FUNC should return nil if it cannot determine the number of ampersands."
  (let* ((cur (point))
         (num
          (save-excursion
            (ignore-errors
              (LaTeX-find-matching-begin)
              ;; Skip over "\begin{xxx}" and possible whitespaces.
              (forward-list 1)
              (skip-chars-forward " \t")
              ;; Skip over the text specified by REGEXP and whitespaces.
              (when (let ((case-fold-search nil))
                      (re-search-forward regexp cur))
                (skip-chars-forward " \t")
                (when (eq (following-char) ?{)
                  ;; We have reached the target "{yyy}" part.
                  (forward-char 1)
                  ;; The next line doesn't move point, so point
                  ;; is left just after the opening brace.
                  (let ((pos (TeX-find-closing-brace)))
                    (if pos
                        ;; Calculate number of ampersands to be inserted.
                        (funcall func (point) (1- pos))))))))))
    (if (natnump num)
        (save-excursion (insert (make-string num ?&))))))

(defvar LaTeX-array-column-letters "clrp"
  "Column letters for array-like environments.
See `LaTeX-array-count-columns' for detail.")

(defun LaTeX-array-count-columns (start end)
  "Count number of ampersands to be inserted.
The columns are specified by the letters found in the string
`LaTeX-array-column-letters' and the number of those letters within the
text between START and END is basically considered to be the number of
columns.  The arguments surrounded between braces such as p{30pt} do not
interfere the count of columns.

Return one less number than the columns, or nil on failing to count the
right number."
  (save-excursion
    (let (p (cols 0))
      (goto-char start)
      (while (< (setq p (point)) end)

        ;; The below block accounts for one unit of move for
        ;; one column.
        (setq cols (+ cols
                      ;; treat *-operator specially.
                      (if (eq (following-char) ?*)
                          ;; *-operator is there.
                          (progn
                            ;; pick up repetition number and count
                            ;; how many columns are repeated.
                            (re-search-forward
                             "\\*[ \t\r\n%]*{[ \t\r\n%]*\\([0-9]+\\)[ \t\r\n%]*}" end)
                            (let ((n (string-to-number
                                      (match-string-no-properties 1)))
                                  ;; get start and end of repeated spec.
                                  (s (progn (down-list 1) (point)))
                                  (e (progn (up-list 1) (1- (point)))))
                              (* n (1+ (LaTeX-array-count-columns s e)))))
                        ;; not *-operator.
                        (skip-chars-forward
                         LaTeX-array-column-letters end))))
        ;; Do not skip over `*' (see above) and `[' (siunitx has `S[key=val]':):
        (skip-chars-forward (concat
                             "^" LaTeX-array-column-letters "*"
                             TeX-grop LaTeX-optop) end)
        (when (or (eq (following-char) ?\{)
                  (eq (following-char) ?\[))
          (forward-list 1))

        ;; Not sure whether this is really necessary or not, but
        ;; prepare for possible infinite loop anyway.
        (when (eq p (point))
          (setq cols nil)
          (goto-char end)))
      ;; The number of ampersands is one less than column.
      (if cols (1- cols)))))

;;; Parser

(defvar LaTeX-auto-style nil)
(defvar LaTeX-auto-arguments nil)
(defvar LaTeX-auto-optional nil)
(defvar LaTeX-auto-env-args nil)
(defvar LaTeX-auto-env-args-with-opt nil)
(defvar LaTeX-auto-xparse-macro nil
  "Information about user defined macros in the current buffer.
This variable contains information after parsing the buffer.")
(defvar LaTeX-auto-xparse-environment nil
  "Information about user defined enviroments in the current buffer.
This variable contains information after parsing the buffer.")

(TeX-auto-add-type "label" "LaTeX")
(TeX-auto-add-type "bibitem" "LaTeX")
(TeX-auto-add-type "environment" "LaTeX")
(TeX-auto-add-type "bibliography" "LaTeX" "bibliographies")
(TeX-auto-add-type "index-entry" "LaTeX" "index-entries")
(TeX-auto-add-type "pagestyle" "LaTeX")
(TeX-auto-add-type "counter" "LaTeX")
(TeX-auto-add-type "length" "LaTeX")
(TeX-auto-add-type "savebox" "LaTeX" "saveboxes")

(defvar LaTeX-auto-minimal-regexp-list
  '(("\\\\document\\(style\\|class\\)\
\\(?:\\[\\(\\(?:[^#\\%]\\|%[^\n\r]*[\n\r]\\)*\\)\\]\\)?\
{\\([^#\\.\n\r]+?\\)}"
     (2 3 1) LaTeX-auto-style)
    ("\\\\use\\(package\\)\\(?:\\[\\([^]]*\\)\\]\\)?\
{\\(\\([^#}\\.%]\\|%[^\n\r]*[\n\r]\\)+?\\)}"
     (2 3 1) LaTeX-auto-style))
  "Minimal list of regular expressions matching LaTeX macro definitions.")

(defvar LaTeX-auto-label-regexp-list
  '(("\\\\label{\\([^\n\r%\\{}]+\\)}" 1 LaTeX-auto-label))
  "List of regular expression matching LaTeX labels only.")

(defvar LaTeX-auto-index-regexp-list
  `((,(concat "\\\\\\(?:index\\|glossary\\)"
              "{\\([^}{]*"
              "\\(?:{[^}{]*"
              "\\(?:{[^}{]*"
              "\\(?:{[^}{]*}[^}{]*\\)*}"
              "[^}{]*\\)*}"
              "[^}{]*\\)*\\)}")
     1 LaTeX-auto-index-entry))
  "List of regular expression matching LaTeX index/glossary entries only.
Regexp allows for up to 3 levels of parenthesis inside the index argument.
This is necessary since index entries may contain commands and stuff.")

(defvar LaTeX-auto-class-regexp-list
  `(;; \RequirePackage[<options>]{<package>}[<date>]
    ("\\\\Require\\(Package\\)\\(?:\\[\\([^]]*\\)\\]\\)?\
{\\([^#\\.\n\r]+?\\)}"
     (2 3 1) LaTeX-auto-style)
    ;; \RequirePackageWithOptions{<package>}[<date>],
    ("\\\\Require\\(Package\\)WithOptions\\(\\){\\([^#\\.\n\r]+?\\)}"
     (2 3 1) LaTeX-auto-style)
    ;; \LoadClass[<options>]{<package>}[<date>]
    ("\\\\Load\\(Class\\)\\(?:\\[\\([^]]*\\)\\]\\)?{\\([^#\\.\n\r]+?\\)}"
     (2 3 1) LaTeX-auto-style)
    ;; \LoadClassWithOptions{<package>}[<date>]
    ("\\\\Load\\(Class\\)WithOptions\\(\\){\\([^#\\.\n\r]+?\\)}"
     (2 3 1) LaTeX-auto-style)
    ;; \DeclareRobustCommand{<cmd>}[<num>][<default>]{<definition>},
    ;; \DeclareRobustCommand*{<cmd>}[<num>][<default>]{<definition>}
    ("\\\\DeclareRobustCommand\\*?{?\\\\\\([A-Za-z]+\\)}?\
\\[\\([0-9]+\\)\\]\\[\\([^\n\r]*?\\)\\]"
     (1 2 3) LaTeX-auto-optional)
    ("\\\\DeclareRobustCommand\\*?{?\\\\\\([A-Za-z]+\\)}?\\[\\([0-9]+\\)\\]"
     (1 2) LaTeX-auto-arguments)
    ("\\\\DeclareRobustCommand\\*?{?\\\\\\([A-Za-z]+\\)}?"
     1 TeX-auto-symbol)
    ;; Patterns for commands described in "LaTeX2e font selection" (fntguide)
    (,(concat "\\\\"
              (regexp-opt '("DeclareMathSymbol"  "DeclareMathDelimiter"
                            "DeclareMathAccent"  "DeclareMathRadical"
                            "DeclareTextCommand" "DeclareTextSymbol"
                            "DeclareTextAccent"  "DeclareTextComposite"
                            "ProvideTextCommand" "ProvideTextSymbol"
                            "ProvideTextAccent"  "ProvideTextComposite"
                            "DeclareFixedFont"
                            "DeclareTextFontCommand"
                            "DeclareOldFontCommand"))
              "{?\\\\\\([A-Za-z]+\\)}?")
     1 TeX-auto-symbol))
  "List of regular expressions matching macros in LaTeX classes and packages.")

(defvar LaTeX-auto-pagestyle-regexp-list
  '(("\\\\ps@\\([A-Za-z]+\\)" 1 LaTeX-auto-pagestyle))
  "List of regular expressions matching LaTeX pagestyles only.")

(defvar LaTeX-auto-counter-regexp-list
  (let ((token TeX-token-char))
    `((,(concat "\\\\"
                "\\(?:newcounter\\|@definecounter\\) *{\\(" token "+\\)}")
       1 LaTeX-auto-counter)))
  "List of regular expressions matching LaTeX counters only.")

(defvar LaTeX-auto-length-regexp-list
  (let ((token TeX-token-char))
    `((,(concat "\\\\newlength *{?\\\\\\(" token "+\\)}?") 1 LaTeX-auto-length)))
  "List of regular expressions matching LaTeX lengths only.")

(defvar LaTeX-auto-savebox-regexp-list
  '(("\\\\newsavebox *{?\\\\\\([A-Za-z]+\\)}?" 1 LaTeX-auto-savebox))
  "List of regular expressions matching LaTeX saveboxes only.")

(defvar LaTeX-auto-regexp-list
  (append
   (let ((token TeX-token-char))
     `((,(concat "\\\\\\(re\\)?\\(?:new\\|provide\\)command\\*?"
                 "{?\\\\\\(" token "+\\)}?\\[\\([0-9]+\\)\\]\\[\\([^\n\r]*\\)\\]")
        (2 3 4 1) LaTeX-auto-optional)
       (,(concat "\\\\\\(re\\)?\\(?:new\\|provide\\)command\\*?"
                 "{?\\\\\\(" token "+\\)}?\\[\\([0-9]+\\)\\]")
        (2 3 1) LaTeX-auto-arguments)
       (,(concat "\\\\\\(?:new\\|provide\\)command\\*?{?\\\\\\(" token "+\\)}?")
        1 TeX-auto-symbol)
       (,(concat
          "\\\\\\(New\\|Renew\\|Provide\\|Declare\\)"
          "\\(?:Expandable\\)?"
          "DocumentCommand"
          "[ \t\n\r]*"
          "{?"
          "[ \t\n\r]*"
          "\\\\\\(" token "+\\)"
          "[ \t\n\r]*"
          "}?"
          "[ \t\n\r]*"
          "{\\([^}{]*\\(?:{[^}{]*\\(?:{[^}{]*\\(?:{[^}{]*}[^}{]*\\)*}[^}{]*\\)*}[^}{]*\\)*\\)}")
        (0 2 3 1) LaTeX-auto-xparse-macro)
       ("\\\\\\(re\\)?newenvironment\\*?{\\([^}]+\\)}\\[\\([0-9]+\\)\\]\\["
        (2 3 1) LaTeX-auto-env-args-with-opt)
       ("\\\\\\(re\\)?newenvironment\\*?{\\([^}]+\\)}\\[\\([0-9]+\\)\\]"
        (2 3 1) LaTeX-auto-env-args)
       ("\\\\newenvironment\\*?{\\([^}]+\\)}"
        1 LaTeX-auto-environment)
       (,(concat
          "\\\\\\(New\\|Renew\\|Provide\\|Declare\\)"
          "DocumentEnvironment"
          "[ \t\n\r]*"
          "{[ \t]*\\([^}]+?\\)[ \t]*}"
          "[ \t\n\r]*"
          "{\\([^}{]*\\(?:{[^}{]*\\(?:{[^}{]*\\(?:{[^}{]*}[^}{]*\\)*}[^}{]*\\)*}[^}{]*\\)*\\)}")
        (0 2 3 1) LaTeX-auto-xparse-environment)
       (,(concat "\\\\newtheorem{\\(" token "+\\)}") 1 LaTeX-auto-environment)
       ("\\\\input{\"?\\([^#}%\"\\\n\r]+?\\)\\(?:\\.[^#}%/\"\\.\n\r]+\\)?\"?}"
        1 TeX-auto-file)
       ("\\\\include{\\(\\.*[^#}%\\.\n\r]+\\)\\(\\.[^#}%\\.\n\r]+\\)?}"
        1 TeX-auto-file)
       (,(concat "\\\\bibitem\\(?:\\[[^][\n\r]+\\]\\)?"
                 "{\\(" token "[^, \n\r\t%\"#'()={}]*\\)}")
        1 LaTeX-auto-bibitem)
       ("\\\\bibliography{\\([^#}\\\n\r]+\\)}" 1 LaTeX-auto-bibliography)
       ("\\\\addbibresource\\(?:\\[[^]]+\\]\\)?{\\([^#}\\\n\r]+\\)\\..+}"
        1 LaTeX-auto-bibliography)
       ("\\\\add\\(?:global\\|section\\)bib\\(?:\\[[^]]+\\]\\)?{\\([^#}\\\n\r.]+\\)\\(?:\\..+\\)?}" 1 LaTeX-auto-bibliography)
       ("\\\\\\(?:newrefsection\\|begin{refsection}\\)\\[\\([^]]+\\)\\]"
        1 LaTeX-split-bibs)))
   LaTeX-auto-class-regexp-list
   LaTeX-auto-label-regexp-list
   LaTeX-auto-index-regexp-list
   LaTeX-auto-minimal-regexp-list
   LaTeX-auto-pagestyle-regexp-list
   LaTeX-auto-counter-regexp-list
   LaTeX-auto-length-regexp-list
   LaTeX-auto-savebox-regexp-list)
  "List of regular expression matching common LaTeX macro definitions.")

(defun LaTeX-split-bibs (match)
  "Extract bibliography resources from MATCH.
Split the string at commas and remove Biber file extensions."
  (let ((bibs (split-string (TeX-match-buffer match) " *, *")))
    (dolist (bib bibs)
      (LaTeX-add-bibliographies (replace-regexp-in-string
                                 (concat "\\(?:\\."
                                         (mapconcat #'identity
                                                    TeX-Biber-file-extensions
                                                    "\\|\\.")
                                         "\\)")
                                 "" bib)))))

(defun LaTeX-auto-prepare ()
  "Prepare for LaTeX parsing."
  (setq LaTeX-auto-arguments nil
        LaTeX-auto-optional nil
        LaTeX-auto-env-args nil
        LaTeX-auto-style nil
        LaTeX-auto-end-symbol nil
        LaTeX-auto-xparse-macro nil
        LaTeX-auto-xparse-environment nil))

(add-hook 'TeX-auto-prepare-hook #'LaTeX-auto-prepare)

(defun LaTeX-listify-package-options (options)
  "Return a list from a comma-separated string of package OPTIONS.
The input string may include LaTeX comments and newlines."
  ;; We jump through all those hoops and don't just use `split-string'
  ;; or the like in order to be able to deal with key=value package
  ;; options which can look like this: "pdftitle={A Perfect Day},
  ;; colorlinks=false"
  (let (opts match start)
    (with-temp-buffer
      (set-syntax-table LaTeX-mode-syntax-table)
      (insert options)
      (newline) ; So that the last entry can be found.
      (goto-char (point-min))
      (setq start (point))
      (while (re-search-forward "[{ ,%\n\r]" nil t)
        (setq match (match-string 0))
        (cond
         ;; Step over groups.  (Let's hope nobody uses escaped braces.)
         ((string= match "{")
          (up-list))
         ;; Get rid of whitespace.
         ((string= match " ")
          (delete-region (1- (point))
                         (save-excursion
                           (skip-chars-forward " ")
                           (point))))
         ;; Add entry to output.
         ((or (string= match ",") (= (point) (point-max)))
          (let ((entry (buffer-substring-no-properties
                        start (1- (point)))))
            (unless (member entry opts)
              (setq opts (append opts (list entry)))))
          (setq start (point)))
         ;; Get rid of comments.
         ((string= match "%")
          (delete-region (1- (point))
                         (line-beginning-position 2)))
         ;; Get rid of newlines.
         ((or (string= match "\n") (string= match "\r"))
          (delete-char -1)))))
    opts))

(defvar-local LaTeX-provided-class-options nil
  "Alist of options provided to LaTeX classes.
For each element, the CAR is the name of the class, the CDR is
the list of options provided to it.

For example, its value will be
  ((\"book\" \"a4paper\" \"11pt\" \"openany\" \"fleqn\")
   ...)
See also `LaTeX-provided-package-options'.")

(add-to-list 'TeX-normal-mode-reset-list 'LaTeX-provided-class-options)

(defun LaTeX-provided-class-options-member (class option)
  "Return non-nil if OPTION has been given to CLASS at load time.
The value is actually the tail of the list of options given to CLASS."
  (member option (cdr (assoc class LaTeX-provided-class-options))))

(defun LaTeX-match-class-option (regexp)
  "Check if a documentclass option matching REGEXP is active.
Return first found class option matching REGEXP, or nil if not found."
  (TeX-member regexp (apply #'append
                            (mapcar #'cdr LaTeX-provided-class-options))
              #'string-match))

(defvar-local LaTeX-provided-package-options nil
  "Alist of options provided to LaTeX packages.
For each element, the CAR is the name of the package, the CDR is
the list of options provided to it.

For example, its value will be
  ((\"babel\" \"german\")
   (\"geometry\" \"a4paper\" \"top=2cm\" \"bottom=2cm\" \"left=2.5cm\" \"right=2.5cm\")
   ...)
See also `LaTeX-provided-class-options'.")

(add-to-list 'TeX-normal-mode-reset-list 'LaTeX-provided-package-options)

(defun LaTeX-provided-package-options-member (package option)
  "Return non-nil if OPTION has been given to PACKAGE at load time.
The value is actually the tail of the list of options given to PACKAGE."
  (member option (cdr (assoc package LaTeX-provided-package-options))))

(defun LaTeX-arg-xparse-embellishment (_optional embellish)
  "Special insert function for embellishments.
Compatibility argument OPTIONAL is ignored.  EMBELLISH is a
string with parsed elements inserted in the buffer.  This
function also sets the value of `TeX-exit-mark' where the point
will be once the insertion is completed."
  (let (p)
    (just-one-space)
    (setq p (point))
    (insert embellish)
    (set-marker TeX-exit-mark (1+ p))))

(defun LaTeX-xparse-macro-parse (type)
  "Process parsed macro and environment definitions.
TYPE is one of the symbols mac or env."
  (dolist (xcmd (if (eq type 'mac)
                    LaTeX-auto-xparse-macro
                  LaTeX-auto-xparse-environment))
    (let ((name (string-trim (nth 1 xcmd) "[ \t\r\n%]+" "[ \t\r\n%]+"))
          (spec (nth 2 xcmd))
          (what (nth 3 xcmd))
          (case-fold-search nil)
          (syntax (TeX-search-syntax-table ?\{ ?\}))
          args opt-star opt-token)
      (with-temp-buffer
        (set-syntax-table LaTeX-mode-syntax-table)
        (insert (replace-regexp-in-string "[ \t\r\n%]" "" spec))
        (goto-char (point-min))
        (while (looking-at-p "[+!>=bcmrRvodODsteE]")
          (cond ((looking-at-p "[+!bc]")
                 ;; + or !: Long argument or space aware: Move over
                 ;; them.  b is special; only available for
                 ;; enviroments as well as c.
                 (forward-char 1))
                ;; Argument processors and key-val modifier: Move
                ;; over [>=] and a balanced {}
                ((looking-at-p "[>=]")
                 (forward-char 1)
                 (with-syntax-table syntax (forward-sexp)))
                ;; Mandatory arguments:
                ;; m: Ask for input with "Text" as prompt
                ((looking-at-p "m")
                 (forward-char 1)
                 (push "Text" args))
                ;; r<token1><token2>
                ((looking-at-p "r")
                 (re-search-forward "r\\(.\\)\\(.\\)" (+ (point) 3) t)
                 (push `(TeX-arg-string nil nil nil nil
                                        ,(match-string-no-properties 1)
                                        ,(match-string-no-properties 2))
                       args))
                ;; R<token1><token2>{default}
                ((looking-at-p "R")
                 (re-search-forward "R\\(.\\)\\(.\\)" (+ (point) 3) t)
                 (with-syntax-table syntax (forward-sexp))
                 (push `(TeX-arg-string nil nil nil nil
                                        ,(match-string-no-properties 1)
                                        ,(match-string-no-properties 2))
                       args))
                ;; v: Use `TeX-arg-verb-delim-or-brace'
                ((looking-at-p "v")
                 (forward-char 1)
                 (push #'TeX-arg-verb-delim-or-brace args))
                ;; Optional arguments:
                ;; o standard LaTeX optional in square brackets
                ((looking-at-p "o")
                 (forward-char 1)
                 (push (vector "Text") args))
                ;; d<token1><token2>
                ((looking-at-p "d")
                 (re-search-forward "d\\(.\\)\\(.\\)" (+ (point) 3) t)
                 (push (vector #'TeX-arg-string nil nil nil nil
                               (match-string-no-properties 1)
                               (match-string-no-properties 2))
                       args))
                ;; O{default}
                ((looking-at-p "O")
                 (forward-char 1)
                 (with-syntax-table syntax (forward-sexp))
                 (push (vector "Text") args))
                ;; D<token1><token2>{default}
                ((looking-at-p "D")
                 (re-search-forward "D\\(.\\)\\(.\\)" (+ (point) 3) t)
                 (with-syntax-table syntax (forward-sexp))
                 (push (vector #'TeX-arg-string nil nil nil nil
                               (match-string-no-properties 1)
                               (match-string-no-properties 2))
                       args))
                ;; s: optional star
                ((looking-at-p "s")
                 (forward-char 1)
                 (setq opt-star t))
                ;; t: optional <token>
                ((looking-at-p "t")
                 (re-search-forward "t\\(.\\)" (+ (point) 2) t)
                 (setq opt-token (match-string-no-properties 1)))
                ;; e{tokes} a set of optional embellishments
                ((looking-at-p "e")
                 (forward-char)
                 (if (looking-at-p TeX-grop)
                     (re-search-forward "{\\([^}]+\\)}" nil t)
                   (re-search-forward "\\(.\\)" (1+ (point)) t))
                 (push `(LaTeX-arg-xparse-embellishment
                         ,(match-string-no-properties 1))
                       args))
                ;; E{tokes}{defaults}
                ((looking-at-p "E")
                 (forward-char)
                 (if (looking-at-p TeX-grop)
                     (re-search-forward "{\\([^}]+\\)}" nil t)
                   (re-search-forward "\\(.\\)" (1+ (point)) t))
                 (push `(LaTeX-arg-xparse-embellishment
                         ,(match-string-no-properties 1))
                       args)
                 (when (looking-at-p TeX-grop)
                   (with-syntax-table syntax (forward-sexp))))
                ;; Finished:
                (t nil))))
      (if (eq type 'env)
          ;; Parsed enviroments: If we are Renew'ing or Delare'ing, we
          ;; delete the enviroment first from `LaTeX-auto-environment'
          ;; before adding the new one:
          (progn
            (when (member what '("Renew" "Declare"))
              (setq LaTeX-auto-environment
                    (assq-delete-all (car (assoc name LaTeX-auto-environment))
                                     LaTeX-auto-environment)))
            (add-to-list 'LaTeX-auto-environment
                         (if args
                             `(,name LaTeX-env-args ,@(reverse args))
                           (list name))))
        ;; Parsed macros: If we are Renew'ing or Delare'ing, we delete
        ;; the macros first from `TeX-auto-symbol' before adding the new
        ;; ones:
        (when (member what '("Renew" "Declare"))
          (setq TeX-auto-symbol
                (assq-delete-all (car (assoc name TeX-auto-symbol))
                                 TeX-auto-symbol))
          (when opt-star
            (setq TeX-auto-symbol
                  (assq-delete-all (car (assoc (concat name "*")
                                               TeX-auto-symbol))
                                   TeX-auto-symbol)))
          (when opt-token
            (setq TeX-auto-symbol
                  (assq-delete-all (car (assoc (concat name opt-token)
                                               TeX-auto-symbol))
                                   TeX-auto-symbol))))
        (add-to-list 'TeX-auto-symbol (cons name (reverse args)))
        (when opt-star
          (add-to-list 'TeX-auto-symbol (cons (concat name "*")
                                              (reverse args))))
        (when opt-token
          (add-to-list 'TeX-auto-symbol (cons (concat name opt-token)
                                              (reverse args))))))))

(defun LaTeX-auto-cleanup ()
  "Cleanup after LaTeX parsing."

  ;; Cleanup BibTeX/Biber files
  (setq LaTeX-auto-bibliography
        (apply #'append (mapcar (lambda (arg)
                                  (split-string arg ","))
                                LaTeX-auto-bibliography)))

  ;; Cleanup document classes and packages
  (unless (null LaTeX-auto-style)
    (while LaTeX-auto-style
      (let* ((entry (car LaTeX-auto-style))
             (options (nth 0 entry))
             (style (nth 1 entry))
             (class (nth 2 entry)))

        ;; Next document style.
        (setq LaTeX-auto-style (cdr LaTeX-auto-style))

        ;; Get the options.
        (setq options (LaTeX-listify-package-options options))

        ;; Treat documentclass/documentstyle specially.
        (if (or (string-equal "package" class)
                (string-equal "Package" class))
            (dolist (elt (split-string
                          style "\\([ \t\r\n]\\|%[^\n\r]*[\n\r]\\|,\\)+"))
              ;; Append style to the style list.
              (add-to-list 'TeX-auto-file elt t)
              ;; Append to `LaTeX-provided-package-options' the name of the
              ;; package and the options provided to it at load time.
              (TeX-add-to-alist 'LaTeX-provided-package-options
                                (list (cons elt options))))
          ;; And a special "art10" style file combining style and size.
          (add-to-list 'TeX-auto-file style t)
          (add-to-list 'TeX-auto-file
                       (concat
                        (cond ((string-equal "article" style)
                               "art")
                              ((string-equal "book" style)
                               "bk")
                              ((string-equal "report" style)
                               "rep")
                              ((string-equal "jarticle" style)
                               "jart")
                              ((string-equal "jbook" style)
                               "jbk")
                              ((string-equal "jreport" style)
                               "jrep")
                              ((string-equal "j-article" style)
                               "j-art")
                              ((string-equal "j-book" style)
                               "j-bk")
                              ((string-equal "j-report" style )
                               "j-rep")
                              (t style))
                        (cond ((member "11pt" options)
                               "11")
                              ((member "12pt" options)
                               "12")
                              (t
                               "10")))
                       t)
          (TeX-add-to-alist 'LaTeX-provided-class-options
                            (list (cons style options))))

        ;; The third argument if "class" indicates LaTeX2e features.
        (cond ((or (string-equal class "class")
                   (string-equal class "Class"))
               (add-to-list 'TeX-auto-file "latex2e"))
              ((string-equal class "style")
               (add-to-list 'TeX-auto-file "latex2"))))))

  ;; Cleanup optional arguments
  (mapc (lambda (entry)
          ;; If we're renewcommand-ing and there is already an entry
          ;; in `TeX-auto-symbol', delete it first:
          (when (and (string= (nth 2 entry) "re")
                     (assoc (car entry) TeX-auto-symbol))
            (setq TeX-auto-symbol
                  (assq-delete-all (car (assoc (car entry)
                                               TeX-auto-symbol))
                                   TeX-auto-symbol)))
          (add-to-list 'TeX-auto-symbol
                       (list (nth 0 entry)
                             (string-to-number (nth 1 entry)))))
        LaTeX-auto-arguments)

  ;; Cleanup for marcos defined with former xparse commands:
  (LaTeX-xparse-macro-parse 'mac)

  ;; Cleanup default optional arguments
  (mapc (lambda (entry)
          ;; If we're renewcommand-ing and there is already an entry
          ;; in `TeX-auto-symbol', delete it first:
          (when (and (string= (nth 3 entry) "re")
                     (assoc (car entry) TeX-auto-symbol))
            (setq TeX-auto-symbol
                  (assq-delete-all (car (assoc (car entry)
                                               TeX-auto-symbol))
                                   TeX-auto-symbol)))
          (add-to-list 'TeX-auto-symbol
                       (list (nth 0 entry)
                             (vector "argument")
                             (1- (string-to-number (nth 1 entry))))))
        LaTeX-auto-optional)

  ;; Cleanup environments arguments
  (mapc (lambda (entry)
          ;; If we're renewenvironment-ing and there is already an
          ;; entry in `LaTeX-auto-environment', delete it first:
          (when (and (string= (nth 2 entry) "re")
                     (assoc (car entry) LaTeX-auto-environment))
            (setq LaTeX-auto-environment
                  (assq-delete-all (car (assoc (car entry)
                                               LaTeX-auto-environment))
                                   LaTeX-auto-environment)))
          (add-to-list 'LaTeX-auto-environment
                       (list (nth 0 entry)
                             (string-to-number (nth 1 entry)))))
        LaTeX-auto-env-args)

  ;; Ditto for environments with an optional arg
  (mapc (lambda (entry)
          ;; If we're renewenvironment-ing and there is already an
          ;; entry in `LaTeX-auto-environment', delete it first:
          (when (and (string= (nth 2 entry) "re")
                     (assoc (car entry) LaTeX-auto-environment))
            (setq LaTeX-auto-environment
                  (assq-delete-all (car (assoc (car entry)
                                               LaTeX-auto-environment))
                                   LaTeX-auto-environment)))
          (add-to-list 'LaTeX-auto-environment
                       (list (nth 0 entry) #'LaTeX-env-args (vector "argument")
                             (1- (string-to-number (nth 1 entry))))))
        LaTeX-auto-env-args-with-opt)

  ;; Cleanup for enviroments defined with former xparse commands:
  (LaTeX-xparse-macro-parse 'env)

  ;; Cleanup use of def to add environments
  ;; NOTE: This uses an O(N^2) algorithm, while an O(N log N)
  ;; algorithm is possible.
  (mapc (lambda (symbol)
          (if (not (TeX-member symbol TeX-auto-symbol #'equal))
              ;; No matching symbol, insert in list
              (add-to-list 'TeX-auto-symbol (concat "end" symbol))
            ;; Matching symbol found, remove from list
            (if (equal (car TeX-auto-symbol) symbol)
                ;; Is it the first symbol?
                (setq TeX-auto-symbol (cdr TeX-auto-symbol))
              ;; Nope!  Travel the list
              (let ((list TeX-auto-symbol))
                (while (consp (cdr list))
                  ;; Until we find it.
                  (if (equal (car (cdr list)) symbol)
                      ;; Then remove it.
                      (setcdr list (cdr (cdr list))))
                  (setq list (cdr list)))))
            ;; and add the symbol as an environment.
            (add-to-list 'LaTeX-auto-environment symbol)))
        LaTeX-auto-end-symbol))

(add-hook 'TeX-auto-cleanup-hook #'LaTeX-auto-cleanup)

(advice-add 'LaTeX-add-bibliographies :after #'TeX-run-style-hooks)

;;; Biber support

(defvar-local LaTeX-using-Biber nil
  "Used to track whether Biber is in use.")

;;; BibTeX

(defvar BibTeX-auto-regexp-list
  '(("@[Ss][Tt][Rr][Ii][Nn][Gg]" 1 ignore)
    ("@[a-zA-Z]+[{(][ \t]*\\([^, \n\r\t%\"#'()={}]*\\)" 1 LaTeX-auto-bibitem))
  "List of regexp-list expressions matching BibTeX items.")

;;;###autoload
(defun BibTeX-auto-store ()
  "This function should be called from `bibtex-mode-hook'.
It will setup BibTeX to store keys in an auto file."
  ;; We want this to be early in the list, so we do not
  ;; add it before we enter BibTeX mode the first time.
  (add-hook 'write-contents-functions #'TeX-safe-auto-write nil t)
  (TeX-bibtex-set-BibTeX-dialect)
  (setq-local TeX-auto-untabify nil)
  (setq-local TeX-auto-parse-length 999999)
  (setq-local TeX-auto-regexp-list BibTeX-auto-regexp-list)
  (setq-local TeX-master t))

;;; Macro Argument Hooks

(defun TeX-arg-conditional (_optional expr then else)
  "Implement if EXPR THEN ELSE.

If EXPR evaluate to true, parse THEN as an argument list, else
parse ELSE as an argument list.  The compatibility argument
OPTIONAL is ignored."
  (declare (indent 2))
  (TeX-parse-arguments (if (eval expr t) then else)))

(defun TeX-arg-eval (optional &rest args)
  "Evaluate ARGS and insert value in buffer.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one."
  (TeX-argument-insert (eval args t) optional))

(defun TeX-read-label (optional &optional prompt definition)
  "Prompt for a label completing with known labels and return it.
This function always returns a string depending on user input:
the returned value can be an empty string \"\", the value of
`TeX-read-label-prefix' if present (for example, \"fig:\") or a
complete label input (for example, \"fig:foo\").  If OPTIONAL is
non-nil, indicate optional as part of prompt in minibuffer.  Use
PROMPT as the prompt string.  If DEFINITION is non-nil, add the
chosen label to the list of defined labels.
`TeX-read-label-prefix' is used as initial input for the label.
Also check if label is already defined and ask user for
confirmation before proceeding."
  (let (label valid)
    (while (not valid)
      (setq label
            (completing-read
             (TeX-argument-prompt optional prompt "Key")
             (LaTeX-label-list) nil nil TeX-read-label-prefix))
      ;; If we're defining a label, check if it's already defined and
      ;; ask user for confirmation, otherwise ask again
      (cond ((and definition
                  (assoc label (LaTeX-label-list)))
             (ding)
             (when (y-or-n-p
                    (format-message "Label `%s' exists. Use anyway? " label))
               (setq valid t)))
            (t
             (setq valid t))))
    ;; Only add a newly defined label to list of known one if it is
    ;; not empty and not equal to `TeX-read-label-prefix', if given
    (when (and definition
               (not (string-equal "" label))
               (if TeX-read-label-prefix
                   (not (string-equal TeX-read-label-prefix label))
                 t))
      (LaTeX-add-labels label))
    ;; Return label, can be empty string "", TeX-read-label-prefix
    ;; only "fig:" or the real thing like "fig:foo"
    label))

(defun TeX-arg-label (optional &optional prompt definition)
  "Prompt for a label completing with known labels.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  If DEFINITION is non-nil, add the chosen label to the
list of defined labels.  `TeX-read-label-prefix' is used as
initial input for the label."
  (TeX-argument-insert
   (TeX-read-label optional prompt definition) optional))

(defvar reftex-ref-macro-prompt)

(defun TeX-arg-ref (optional &optional prompt definition)
  "Let-bind `reftex-ref-macro-prompt' to nil and call `TeX-arg-label'.

All arguments are passed to `TeX-arg-label'.  See the documentation of
`TeX-arg-label' for details on the arguments: OPTIONAL, PROMPT, and
DEFINITION."
  (let ((reftex-ref-macro-prompt nil))
    (TeX-arg-label optional prompt definition)))

(defun TeX-arg-index-tag (optional &optional prompt &rest _args)
  "Prompt for an index tag.
This is the name of an index, not the entry.

If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  ARGS is unused."
  (TeX-argument-insert
   (TeX-read-string (TeX-argument-prompt optional prompt "Index tag"))
   optional))

(defun TeX-arg-index (optional &optional prompt &rest _args)
  "Prompt for an index entry completing with known entries.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  ARGS is unused."
  (let ((entry (completing-read (TeX-argument-prompt optional prompt "Key")
                                (LaTeX-index-entry-list))))
    (if (and (not (string-equal "" entry))
             (not (member (list entry) (LaTeX-index-entry-list))))
        (LaTeX-add-index-entries entry))
    (TeX-argument-insert entry optional)))

(defalias 'TeX-arg-define-index #'TeX-arg-index)

(defun TeX-arg-macro (optional &optional prompt definition)
  "Prompt for a TeX macro with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  If DEFINITION is non-nil, add the chosen macro to the
list of defined macros."
  (let ((macro (completing-read (TeX-argument-prompt optional prompt
                                                     (concat "Macro: "
                                                             TeX-esc)
                                                     t)
                                (TeX-symbol-list))))
    (if (and definition (not (string-equal "" macro)))
        (TeX-add-symbols macro))
    (TeX-argument-insert macro optional TeX-esc)))

(defun TeX-arg-environment (optional &optional prompt definition)
  "Prompt for a LaTeX environment with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  If DEFINITION is non-nil, add the chosen environment to
the list of defined environments."
  (let ((environment (completing-read (TeX-argument-prompt optional prompt
                                                           "Environment")
                                      (LaTeX-environment-list))))
    (if (and definition (not (string-equal "" environment)))
        (LaTeX-add-environments environment))

    (TeX-argument-insert environment optional)))

;; Why is DEFINITION unused?
(defun TeX-arg-cite (optional &optional prompt _definition)
  "Prompt for a BibTeX citation with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  DEFINITION is unused."
  (let ((items (multi-prompt "," t (TeX-argument-prompt optional prompt "Key")
                             (LaTeX-bibitem-list))))
    (apply #'LaTeX-add-bibitems items)
    (TeX-argument-insert (mapconcat #'identity items ",") optional)))

(defun TeX-arg-counter (optional &optional prompt definition)
  "Prompt for a LaTeX counter.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  If DEFINITION is non-nil, add the chosen counter to
the list of defined counters."
  (let ((counter (completing-read (TeX-argument-prompt optional prompt
                                                       "Counter")
                                  (LaTeX-counter-list))))
    (if (and definition (not (string-equal "" counter)))
        (LaTeX-add-counters counter))
    (TeX-argument-insert counter optional)))

(defun TeX-arg-savebox (optional &optional prompt definition)
  "Prompt for a LaTeX savebox.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  If DEFINITION is non-nil, the savebox is added to the
list of defined saveboxes."
  (let ((savebox (completing-read (TeX-argument-prompt optional prompt
                                                       (concat "Savebox: "
                                                               TeX-esc) t)
                                   (LaTeX-savebox-list))))
    (if (and definition (not (zerop (length savebox))))
        (LaTeX-add-saveboxes savebox))
    (TeX-argument-insert savebox optional TeX-esc)))

(defun TeX-arg-length (optional &optional prompt default initial-input
                                definition)
  "Prompt for a LaTeX length.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  DEFAULT is passed to `completing-read', which see.  If
INITIAL-INPUT is non-nil, insert it in the minibuffer initially,
with point positioned at the end.  If DEFINITION is non-nil, the
length is added to the list of defined length."
  (let ((length
         (completing-read
          (TeX-argument-prompt optional
                               ;; Cater for the case when PROMPT and
                               ;; DEFAULT are both given.  Note that we
                               ;; can't use `format-prompt' here:
                               (if (and prompt default)
                                   (concat prompt " (default " default ")")
                                 prompt)
                               (concat "Length"
                                       (when (and default (not optional))
                                         (concat " (default " default ")"))))
          ;; A valid length can be a macro or a length of the form
          ;; <value><dimension>.  Input starting with a `\' can be
          ;; completed with length macros.
          (mapcar (lambda (elt) (concat TeX-esc (car elt)))
                  (LaTeX-length-list))
          ;; Some macros takes as argument only a length macro (e.g.,
          ;; `\setlength' in its first argument, and `\newlength'), in
          ;; this case is convenient to set `\\' as initial input.
          nil nil initial-input nil default)))
    (if (and definition (not (zerop (length length))))
        ;; Strip leading TeX-esc from macro name
        (LaTeX-add-lengths (substring length 1)))
    (TeX-argument-insert length optional)))

(defun TeX-arg-file (optional &optional prompt)
  "Prompt for a filename in the current directory.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-argument-insert (read-file-name (TeX-argument-prompt optional
                                                            prompt "File")
                                       "" "" nil)
                       optional))

(defun TeX-arg-file-name (optional &optional prompt)
  "Prompt for a file name.
Initial input is the name of the file being visited in the
current buffer, with extension.  If OPTIONAL is non-nil, insert
it as an optional argument.  Use PROMPT as the prompt string."
  (let ((name (file-name-nondirectory (TeX-buffer-file-name))))
    (TeX-argument-insert
     (TeX-read-string
      (TeX-argument-prompt optional
                           (when prompt
                             (if optional
                                 prompt
                               (format (concat prompt " (default %s)") name)))
                           (if optional
                               "Name"
                             (format "Name (default %s)" name)))
      nil nil (if optional nil name))
     optional)))

(defun TeX-arg-file-name-sans-extension (optional &optional prompt)
  "Prompt for a file name.
Initial input is the name of the file being visited in the
current buffer, without extension.  If OPTIONAL is non-nil,
insert it as an optional argument.  Use PROMPT as the prompt
string."
  (let ((name (file-name-sans-extension
               (file-name-nondirectory (TeX-buffer-file-name)))))
    (TeX-argument-insert
     (TeX-read-string
      (TeX-argument-prompt optional
                           (when prompt
                             (if optional
                                 prompt
                               (format (concat prompt " (default %s)") name)))
                           (if optional
                               "Name"
                             (format "Name (default %s)" name)))
      nil nil (if optional nil name))
     optional)))

(defun TeX-arg-define-label (optional &optional prompt)
  "Prompt for a label completing with known labels.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  `TeX-read-label-prefix' is used as initial input for the
label."
  (TeX-arg-label optional prompt t))

(defun TeX-arg-default-argument-value (optional &optional prompt)
  "Prompt for the default value for the first argument of a LaTeX macro.

If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-argument-insert
   (TeX-read-string
    (TeX-argument-prompt optional prompt "Default value for first argument"))
   optional))

(defun TeX-arg-define-macro-arguments (optional &optional prompt)
  "Prompt for the number of arguments for a LaTeX macro.
If this is non-zero, also prompt for the default value for the
first argument.

If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (let ((arg-count (TeX-read-string
                    (TeX-argument-prompt optional prompt
                                         "Number of arguments"
                                         nil))))
    (unless (or (string= arg-count "0")
                (string= arg-count ""))
      (TeX-argument-insert arg-count optional)
      (unless (string-equal LaTeX-version "2")
        (TeX-arg-default-argument-value optional)))))

(defun TeX-arg-define-macro (optional &optional prompt)
  "Prompt for a TeX macro with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-arg-macro optional prompt t))

(defun TeX-arg-define-environment (optional &optional prompt)
  "Prompt for a LaTeX environment with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-arg-environment optional prompt t))

(defun TeX-arg-define-cite (optional &optional prompt)
  "Prompt for a BibTeX citation.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-arg-cite optional prompt t))

(defun TeX-arg-define-counter (optional &optional prompt)
  "Prompt for a LaTeX counter.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-arg-counter optional prompt t))

(defun TeX-arg-define-savebox (optional &optional prompt)
  "Prompt for a LaTeX savebox.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-arg-savebox optional prompt t))

(defun TeX-arg-define-length (optional &optional prompt)
  "Prompt for a LaTeX length.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-arg-length optional prompt nil "\\" t))

(defcustom LaTeX-style-list '(("amsart")
                              ("amsbook")
                              ("article")
                              ("beamer")
                              ("book")
                              ("dinbrief")
                              ("foils")
                              ("letter")
                              ("memoir")
                              ("minimal")
                              ("prosper")
                              ("report")
                              ("scrartcl")
                              ("scrbook")
                              ("scrlttr2")
                              ("scrreprt")
                              ("slides"))
  "List of document classes offered when inserting a document environment.

If `TeX-arg-input-file-search' is set to t, you will get
completion with all LaTeX classes available in your distribution
and this variable will be ignored."
  :group 'LaTeX-environment
  :type '(repeat (group (string :format "%v"))))

(defvar LaTeX-global-class-files nil
  "List of the LaTeX class files.
Initialized once at the first time you prompt for a LaTeX class.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

;; Add the variable to `TeX-normal-mode-reset-list':
(add-to-list 'TeX-normal-mode-reset-list 'LaTeX-global-class-files)

(defcustom TeX-arg-input-file-search t
  "If `TeX-arg-input-file' should search for files.
If the value is t, files in TeX's search path are searched for
and provided for completion.  The file name is then inserted
without directory and extension.  If the value is nil, the file
name can be specified manually and is inserted with a path
relative to the directory of the current buffer's file and with
extension.  If the value is `ask', you are asked for the method
to use every time `TeX-arg-input-file' is called."
  :group 'LaTeX-macro
  :type '(choice (const t) (const nil) (const ask)))

(defvar TeX-after-document-hook nil
  "List of functions to be run at the end of `TeX-arg-document'.

To insert a hook here, you must insert it in the appropiate style file.")

(defun TeX-arg-document (_optional &optional _ignore)
  "Insert arguments to documentclass.
OPTIONAL and IGNORE are ignored."
  (let* ((TeX-file-extensions '("cls"))
         (crm-separator ",")
         style var options defopt optprmpt)
    (unless LaTeX-global-class-files
      (setq LaTeX-global-class-files
            (if (if (eq TeX-arg-input-file-search 'ask)
                    (not (y-or-n-p "Find class yourself? "))
                  TeX-arg-input-file-search)
                (prog2
                    (message "Searching for LaTeX classes...")
                    (TeX-search-files-by-type 'texinputs 'global t t)
                  (message "Searching for LaTeX classes...done"))
              LaTeX-style-list)))
    (setq style (completing-read
                 (format-prompt "Document class" LaTeX-default-style)
                 LaTeX-global-class-files nil nil nil nil LaTeX-default-style))
    ;; Clean up hook before use.
    (setq TeX-after-document-hook nil)
    (TeX-load-style style)
    (setq var (intern (format "LaTeX-%s-class-options" style)))
    (setq defopt (if (stringp LaTeX-default-options)
                     LaTeX-default-options
                   (mapconcat #'identity LaTeX-default-options ",")))
    (setq optprmpt
          (if (and defopt (not (string-equal defopt "")))
              (format-prompt "Options" defopt)
            "Options: "))
    (if (or (and (boundp var)
                 (listp (symbol-value var)))
            (fboundp var))
        (if (functionp var)
            (setq options (funcall var))
          (when (symbol-value var)
            (setq options
                  (mapconcat #'identity
                             (TeX-completing-read-multiple
                              optprmpt (mapcar #'list (symbol-value var))
                              nil nil nil nil defopt)
                             ","))))
      (setq options (TeX-read-string optprmpt nil nil defopt)))
    (unless (zerop (length options))
      (insert LaTeX-optop options LaTeX-optcl)
      (let ((opts (LaTeX-listify-package-options options)))
        (TeX-add-to-alist 'LaTeX-provided-class-options
                          (list (cons style opts)))))
    (insert TeX-grop style TeX-grcl))

  (TeX-update-style t)
  (run-hooks 'TeX-after-document-hook))

(defvar LaTeX-after-usepackage-hook nil
  "List of functions to be run at the end of `LaTeX-arg-usepackage'.

To insert a hook here, you must insert it in the appropiate style file.")

(defvar TeX-global-input-files nil
  "List of the non-local TeX input files.
Initialized once at the first time you prompt for an input file.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

(defvar TeX-global-input-files-with-extension nil
  "List of the non-local TeX input files with extension.
Initialized once at the first time you prompt for an input file
inside a file hook command.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

(defvar LaTeX-global-package-files nil
  "List of the LaTeX package files.
Initialized once at the first time you prompt for a LaTeX package.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

;; Add the variables to `TeX-normal-mode-reset-list':
(add-to-list 'TeX-normal-mode-reset-list 'TeX-global-input-files)
(add-to-list 'TeX-normal-mode-reset-list 'TeX-global-input-files-with-extension)
(add-to-list 'TeX-normal-mode-reset-list 'LaTeX-global-package-files)

(defun LaTeX-arg-usepackage-read-packages-with-options ()
  "Read the packages and the options for the usepackage macro.

If at least one package is provided, this function returns a cons
cell, whose CAR is the list of packages and the CDR is the string
of the options, nil otherwise."
  (let* ((TeX-file-extensions '("sty"))
         (crm-separator ",")
         packages var options)
    (unless LaTeX-global-package-files
      (if (if (eq TeX-arg-input-file-search 'ask)
              (not (y-or-n-p "Find packages yourself? "))
            TeX-arg-input-file-search)
          (progn
            (message "Searching for LaTeX packages...")
            (setq LaTeX-global-package-files
                  (mapcar #'list (TeX-search-files-by-type
                                  'texinputs 'global t t)))
            (message "Searching for LaTeX packages...done"))))
    (setq packages (TeX-completing-read-multiple
                    "Packages: " LaTeX-global-package-files))
    ;; Clean up hook before use in `LaTeX-arg-usepackage-insert'.
    (setq LaTeX-after-usepackage-hook nil)
    (mapc #'TeX-load-style packages)
    ;; Prompt for options only if at least one package has been supplied, return
    ;; nil otherwise.
    (when packages
      (setq var (if (= 1 (length packages))
                    (intern (format "LaTeX-%s-package-options" (car packages)))
                  ;; Something like `\usepackage[options]{pkg1,pkg2,pkg3,...}' is
                  ;; allowed (provided that pkg1, pkg2, pkg3, ... accept same
                  ;; options).  When there is more than one package, set `var' to
                  ;; a dummy value so next `if' enters else form.
                  t))
      (if (or (and (boundp var)
                   (listp (symbol-value var)))
              (fboundp var))
          (if (functionp var)
              (setq options (funcall var))
            (when (symbol-value var)
              (setq options
                    (mapconcat #'identity
                               (TeX-completing-read-multiple
                                "Options: " (mapcar #'list (symbol-value var)))
                               ","))))
        (setq options (TeX-read-string "Options: ")))
      (cons packages options))))

(defun LaTeX-arg-usepackage-insert (packages options)
  "Actually insert arguments to usepackage."
  (unless (zerop (length options))
    (let ((opts (LaTeX-listify-package-options options)))
      (mapc (lambda (elt)
              (TeX-add-to-alist 'LaTeX-provided-package-options
                                (list (cons elt opts))))
            packages))
    (insert LaTeX-optop options LaTeX-optcl))
  (insert TeX-grop (mapconcat #'identity packages ",") TeX-grcl)
  (run-hooks 'LaTeX-after-usepackage-hook)
  (apply #'TeX-run-style-hooks packages))

(defun LaTeX-arg-usepackage (_optional)
  "Insert arguments to usepackage.
OPTIONAL is ignored."
  (let* ((packages-options (LaTeX-arg-usepackage-read-packages-with-options))
         (packages (car packages-options))
         (options (cdr packages-options)))
    (LaTeX-arg-usepackage-insert packages options)))

(defun LaTeX-insert-usepackages ()
  "Prompt for the insertion of usepackage macros until empty
input is reached.

Return t if at least one \\usepackage has been inserted, nil
otherwise."
  (let (packages-options packages options (inserted nil))
    (while (setq packages-options
                 (LaTeX-arg-usepackage-read-packages-with-options))
      (setq packages (car packages-options))
      (setq options (cdr packages-options))
      (insert TeX-esc "usepackage")
      (LaTeX-arg-usepackage-insert packages options)
      (LaTeX-newline)
      (setq inserted t))
    inserted))

(defcustom LaTeX-search-files-type-alist
  '((texinputs "${TEXINPUTS.latex}" ("tex/generic/" "tex/latex/")
               TeX-file-extensions)
    (docs "${TEXDOCS}" ("doc/") TeX-doc-extensions)
    (graphics "${TEXINPUTS}" ("tex/") LaTeX-includegraphics-extensions)
    (bibinputs "${BIBINPUTS}" ("bibtex/bib/") BibTeX-file-extensions)
    (bstinputs "${BSTINPUTS}" ("bibtex/bst/") BibTeX-style-extensions)
    (bbxinputs "" ("tex/latex/") BibLaTeX-style-extensions)
    (biberinputs "${BIBINPUTS}" ("bibtex/bib/") TeX-Biber-file-extensions))
  "Alist of filetypes with locations and file extensions.
Each element of the alist consists of a symbol expressing the
filetype, a variable which can be expanded on kpathsea-based
systems into the directories where files of the given type
reside, a list of absolute directories, relative directories
below the root of a TDS-compliant TeX tree or a list of variables
with either type of directories as an alternative for
non-kpathsea-based systems and a list of extensions to be matched
upon a file search.  Note that the directories have to end with a
directory separator.

Reset the mode for a change of this variable to take effect."
  :group 'TeX-file
  :type '(alist :key-type symbol
                :value-type
                (group (string :tag "Kpathsea variable")
                       (choice :tag "Directories"
                               (repeat :tag "TDS subdirectories" string)
                               (repeat :tag "Absolute directories" directory)
                               (repeat :tag "Variables" variable))
                       (choice :tag "Extensions"
                               variable (repeat string)))))

(defun TeX-arg-input-file (optional &optional prompt local)
  "Prompt for a tex or sty file.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  PROMPT is the prompt,
LOCAL is a flag.  If the flag is set, only complete with local
files."
  (let ((search (if (eq TeX-arg-input-file-search 'ask)
                    (not (y-or-n-p "Find file yourself? "))
                  TeX-arg-input-file-search))
        file style)
    (if search
        (progn
          (unless (or TeX-global-input-files local)
            (message "Searching for files...")
            (setq TeX-global-input-files
                  (mapcar #'list (TeX-search-files-by-type
                                 'texinputs 'global t t)))
            (message "Searching for files...done"))
          (setq file (completing-read
                      (TeX-argument-prompt optional prompt "File")
                      (TeX-delete-dups-by-car
                       (append (mapcar #'list (TeX-search-files-by-type
                                              'texinputs 'local t t))
                               (unless local
                                 TeX-global-input-files))))
                style file))
      (setq file (read-file-name
                  (TeX-argument-prompt optional prompt "File") nil ""))
      (unless (string-equal file "")
        (setq file (file-relative-name file)))
      (setq style (file-name-sans-extension (file-name-nondirectory file))))
    (unless (string-equal "" style)
      (TeX-run-style-hooks style))
    (TeX-argument-insert file optional)))

(defvar BibTeX-global-style-files nil
  "Association list of BibTeX style files.

Initialized once at the first time you prompt for an input file.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

(defvar BibLaTeX-global-style-files nil
  "Association list of BibLaTeX style files.

Initialized once at the first time you prompt for a BibLaTeX
style.  May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

;; Add both variables to `TeX-normal-mode-reset-list':
(add-to-list 'TeX-normal-mode-reset-list 'BibTeX-global-style-files)
(add-to-list 'TeX-normal-mode-reset-list 'BibLaTeX-global-style-files)

(defun TeX-arg-bibstyle (optional &optional prompt)
  "Prompt for a BibTeX style file.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (message "Searching for BibTeX styles...")
  (or BibTeX-global-style-files
      (setq BibTeX-global-style-files
            (mapcar #'list (TeX-search-files-by-type 'bstinputs 'global t t))))
  (message "Searching for BibTeX styles...done")
  (TeX-argument-insert
   (completing-read (TeX-argument-prompt optional prompt "BibTeX style")
                    (append (mapcar #'list (TeX-search-files-by-type
                                            'bstinputs 'local t t))
                            BibTeX-global-style-files))
   optional))

(defvar BibTeX-global-files nil
  "Association list of BibTeX files.

Initialized once at the first time you prompt for a BibTeX file.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

(defvar TeX-Biber-global-files nil
  "Association list of Biber files.

Initialized once at the first time you prompt for an Biber file.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

(add-to-list 'TeX-normal-mode-reset-list 'BibTeX-global-files)
(add-to-list 'TeX-normal-mode-reset-list 'TeX-Biber-global-files)

(defun TeX-arg-bibliography (optional &optional prompt)
  "Prompt for a BibTeX database file.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (message "Searching for BibTeX files...")
  (or BibTeX-global-files
      (setq BibTeX-global-files
            (mapcar #'list (TeX-search-files-by-type 'bibinputs 'global t t))))
  (message "Searching for BibTeX files...done")
  (let ((styles (multi-prompt
                 "," t
                 (TeX-argument-prompt optional prompt "BibTeX files")
                 (append (mapcar #'list (TeX-search-files-by-type
                                         'bibinputs 'local t t))
                         BibTeX-global-files))))
    (apply #'LaTeX-add-bibliographies styles)
    ;; Run style files associated to the bibliography database files in order to
    ;; immediately fill `LaTeX-bibitem-list'.
    (mapc #'TeX-run-style-hooks styles)
    (TeX-argument-insert (mapconcat #'identity styles ",") optional)))

(defun TeX-arg-corner (optional &optional prompt)
  "Prompt for a LaTeX side or corner position with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-argument-insert
   (completing-read (TeX-argument-prompt optional prompt "Position")
                    '("l" "r" "t" "b" "tl" "tr" "bl" "br"))
   optional))

(defun TeX-arg-lr (optional &optional prompt)
  "Prompt for a LaTeX side with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (TeX-argument-insert
   (completing-read (TeX-argument-prompt optional prompt "Position")
                    '("l" "r"))
   optional))

(defun TeX-arg-tb (optional &optional prompt poslist)
  "Prompt for a LaTeX side with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  POSLIST controls the positioning characters offered for
completion.  It can be the symbols `center', `stretch' or nil
with the following completion list:
  center   t, b, c
  stretch  t, b, c, s
  nil      t, b"
  (TeX-argument-insert
   (completing-read (TeX-argument-prompt optional prompt "Position")
                    (cond ((eq poslist 'center)
                           '("t" "b" "c"))
                          ((eq poslist 'stretch)
                           '("t" "b" "c" "s"))
                          (t
                           '("t" "b"))))
   optional))

(defcustom TeX-date-format "%Y/%m/%d"
  "The default date format prompted by `TeX-arg-date'."
  :group 'LaTeX-macro
  :type 'string)

(defun TeX-arg-date (optional &optional prompt)
  "Prompt for a date, defaulting to the current date.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (let ((default (format-time-string TeX-date-format (current-time))))
    (TeX-argument-insert
     (TeX-read-string
      (TeX-argument-prompt optional
                           (when prompt
                             (format (concat prompt " (default %s)") default))
                           (format "Date (default %s)" default))
      nil nil default)
     optional)))

(defun TeX-arg-version (optional &optional prompt)
  "Prompt for the version of a file.
Use as initial input the current date.  If OPTIONAL is non-nil,
insert the resulting value as an optional argument, otherwise as
a mandatory one.  Use PROMPT as the prompt string."
  (let ((version (format-time-string "%Y/%m/%d" (current-time))))
    (TeX-argument-insert
     (TeX-read-string
      (TeX-argument-prompt optional
                           (when prompt
                             (format (concat prompt " (default %s)") version))
                           (format "Version (default %s)" version))
      nil nil version)
     optional)))

(defun TeX-arg-pagestyle (optional &optional prompt definition)
  "Prompt for a LaTeX pagestyle with completion.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string.  If DEFINITION is non-nil, add the chosen pagestyle to
the list of defined pagestyles."
  (let ((pagestyle (completing-read (TeX-argument-prompt optional prompt
                                                         "Pagestyle")
                                    (LaTeX-pagestyle-list))))
    (if (and definition (not (string-equal "" pagestyle)))
        (LaTeX-add-pagestyles pagestyle))
    (TeX-argument-insert pagestyle optional)))

(defcustom LaTeX-default-verb-delimiter ?|
  "Default delimiter for `\\verb' macros."
  :group 'LaTeX-macro
  :type 'character)

(defun TeX-arg-verb (_optional &optional _ignore)
  "Prompt for delimiter and text.
The compatibility argument OPTIONAL and IGNORE are ignored."
  (let ((del (read-quoted-char
              (format-prompt "Delimiter" (char-to-string
                                          LaTeX-default-verb-delimiter)))))
    (when (<= del ?\ ) (setq del LaTeX-default-verb-delimiter))
    (if (TeX-active-mark)
        (progn
          (insert del)
          (goto-char (mark))
          (insert del))
      (insert del (read-from-minibuffer "Text: ") del))
    (setq LaTeX-default-verb-delimiter del)))

(defun TeX-arg-verb-delim-or-brace (optional &optional prompt)
  "Prompt for delimiter and text.
If OPTIONAL, indicate optional argument in minibuffer.  PROMPT is
a string replacing the default one when asking the user for text.
This function is intended for \\verb like macros which take their
argument in delimiters like \"| |\" or braces \"{ }\"."
  (let ((del (read-quoted-char
              (format-prompt "Delimiter" (char-to-string
                                          LaTeX-default-verb-delimiter)))))
    (when (<= del ?\ )
      (setq del LaTeX-default-verb-delimiter))
    (if (TeX-active-mark)
        (progn
          (insert del)
          (goto-char (mark))
          ;; If the delimiter was an opening brace, close it with a
          ;; brace, otherwise use the delimiter again
          (insert (if (= del ?\{)
                      ?\}
                    del)))
      ;; Same thing again
      (insert del (read-from-minibuffer
                   (TeX-argument-prompt optional prompt "Text"))
              (if (= del ?\{)
                  ?\}
                del)))
    ;; Do not set `LaTeX-default-verb-delimiter' if the user input was
    ;; an opening brace.  This would give funny results for the next
    ;; "C-c C-m \verb RET"
    (unless (= del ?\{)
      (setq LaTeX-default-verb-delimiter del))))

(defun TeX-arg-pair (_optional first second)
  "Insert a pair of number, prompted by FIRST and SECOND.

The numbers are surounded by parenthesizes and separated with a
comma.  The compatibility argument OPTIONAL is ignored."
  (insert "(" (TeX-read-string (concat first  ": ")) ","
          (TeX-read-string (concat second ": ")) ")"))

(defun TeX-arg-size (optional)
  "Insert width and height as a pair.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one."
  (TeX-arg-pair optional "Width" "Height"))

(defun TeX-arg-coordinate (optional)
  "Insert x and y coordinate as a pair.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one."
 (TeX-arg-pair optional "X position" "Y position"))

(defconst TeX-braces-default-association
  '(("[" . "]")
    ("\\{" . "\\}")
    ("(" . ")")
    ("|" . "|")
    ("\\|" . "\\|")
    ("/" . "/")
    ("\\backslash" . "\\backslash")
    ("\\lfloor" . "\\rfloor")
    ("\\lceil" . "\\rceil")
    ("\\langle" . "\\rangle")))

(defcustom TeX-braces-user-association nil
  "A list of your personal association of brace symbols.
These are used for \\left and \\right.

The car of each entry is the brace used with \\left,
the cdr is the brace used with \\right."
  :group 'LaTeX-macro
  :group 'LaTeX-math
  :type '(repeat (cons :format "%v"
                       (string :tag "Left")
                       (string :tag "Right"))))

(defvar TeX-braces-association
  (append TeX-braces-user-association
          TeX-braces-default-association)
    "A list of association of brace symbols for \\left and \\right.
The car of each entry is the brace used with \\left,
the cdr is the brace used with \\right.")

(defcustom LaTeX-electric-left-right-brace nil
  "If non-nil, insert right brace with suitable macro after typing left brace."
  :group 'LaTeX-macro
  :type 'boolean)

(defvar TeX-left-right-braces
  '(("[") ("]") ("\\{") ("\\}") ("(") (")") ("|") ("\\|")
    ("/") ("\\backslash") ("\\lfloor") ("\\rfloor")
    ("\\lceil") ("\\rceil") ("\\langle") ("\\rangle")
    ("\\uparrow") ("\\Uparrow") ("\\downarrow") ("\\Downarrow")
    ("\\updownarrow") ("\\Updownarrow") ("."))
  "List of symbols which can follow the \\left or \\right command.")

(defvar LaTeX-left-right-macros-association
  '(("left" . "right")
    ("bigl" . "bigr") ("Bigl" . "Bigr")
    ("biggl" . "biggr") ("Biggl" . "Biggr"))
  "Alist of macros for adjusting size of left and right braces.
The car of each entry is for left brace and the cdr is for right brace.")

(defun TeX-arg-insert-braces (optional &optional prompt)
  "Prompt for a brace for \\left and insert the corresponding \\right.
If OPTIONAL is non-nil, insert the resulting value as an optional
argument, otherwise as a mandatory one.  Use PROMPT as the prompt
string."
  (let (left-macro)
    (save-excursion
      ;; Obtain macro name such as "left", "bigl" etc.
      (setq left-macro (buffer-substring-no-properties
                        (point)
                        (progn (backward-word 1) (point))))
      (backward-char)
      (LaTeX-newline)
      (indent-according-to-mode)
      ;; Delete possibly produced blank line.
      (beginning-of-line 0)
      (if (looking-at "^[ \t]*$")
          (progn (delete-horizontal-space)
                 (delete-char 1))))
    (let ((left-brace (completing-read
                       (TeX-argument-prompt optional prompt
                                            "Which brace")
                       TeX-left-right-braces)))
      (insert left-brace)
      (LaTeX-newline)
      (save-excursion
        (if (TeX-active-mark)
            (goto-char (mark)))
        (LaTeX-newline)
        (LaTeX-insert-corresponding-right-macro-and-brace
         left-macro left-brace optional prompt)
        (indent-according-to-mode))
      (indent-according-to-mode))))

(defvar TeX-arg-right-insert-p) ;; Defined further below.

(defun TeX-arg-insert-right-brace-maybe (optional)
  "Insert the suitable right brace macro such as \\rangle.
Insertion is done when `TeX-arg-right-insert-p' is non-nil.
If the left brace macro is preceded by \\left, \\bigl etc.,
supply the corresponding macro such as \\right before the right brace macro."
  ;; Nothing is done when TeX-arg-right-insert-p is nil.
  (when TeX-arg-right-insert-p
    (let (left-brace left-macro)
      (save-excursion
        ;; Obtain left brace macro name such as "\langle".
        (setq left-brace (buffer-substring-no-properties
                          (point)
                          (progn (backward-word) (backward-char)
                                 (point)))
              ;; Obtain the name of preceding left macro, if any,
              ;; such as "left", "bigl" etc.
              left-macro (LaTeX--find-preceding-left-macro-name)))
      (save-excursion
        (if (TeX-active-mark)
            (goto-char (mark)))
        (LaTeX-insert-corresponding-right-macro-and-brace
         left-macro left-brace optional)))))

(defun LaTeX-insert-left-brace-electric (brace)
  "Insert typed left BRACE and a corresponding right brace.

BRACE should be a character.  See `LaTeX-insert-left-brace' for
allowed BRACE values."
  (when (and (TeX-active-mark) (> (point) (mark)))
    (exchange-point-and-mark))
  (let ((lbrace (char-to-string brace)) lmacro skip-p)
    ;; Use `insert' rather than `self-insert-command' so that
    ;; unexpected side effects from `post-self-insert-hook',
    ;; e.g. `electric-pair-mode', won't mess up the following
    ;; outcomes. (bug#47936)
    (insert brace)
    (save-excursion
      (backward-char)
      ;; The brace "{" is exceptional in two aspects.
      ;; 1. "\{" should be considered as a single brace
      ;;    like "(" and "[".
      ;; 2. "\left{" is nonsense while "\left\{" and
      ;;    "\left(" are not.
      (if (string= lbrace TeX-grop)
          ;; If "{" follows "\", set lbrace to "\{".
          (if (TeX-escaped-p)
              (progn
                (backward-char)
                (setq lbrace (concat TeX-esc TeX-grop)))
            ;; Otherwise, don't search for left macros.
            (setq skip-p t)))
      (unless skip-p
        ;; Obtain the name of preceding left macro, if any,
        ;; such as "left", "bigl" etc.
        (setq lmacro (LaTeX--find-preceding-left-macro-name))))
    (let ((TeX-arg-right-insert-p t)
          ;; "{" and "}" are paired temporally so that typing
          ;; a single "{" should insert a pair "{}".
          (TeX-braces-association
           (cons (cons TeX-grop TeX-grcl) TeX-braces-association)))
      (save-excursion
        (if (TeX-active-mark)
            (goto-char (mark)))
        (LaTeX-insert-corresponding-right-macro-and-brace
         lmacro lbrace)))))

(defun LaTeX-insert-left-brace (arg)
  "Insert typed left brace ARG times and possibly a corresponding right brace.
Automatic right brace insertion is done only if no prefix ARG is given and
`LaTeX-electric-left-right-brace' is non-nil.
Normally bound to keys \(, { and [."
  (interactive "*P")
  (if (and LaTeX-electric-left-right-brace (not arg))
      (LaTeX-insert-left-brace-electric last-command-event)
    (self-insert-command (prefix-numeric-value arg))))

;; Cater for `delete-selection-mode' (bug#36385). See the header
;; comment of delsel.el for detail.  In short, whenever a function
;; performs insertion, we ``inherit'' the `delete-selection' property.
(TeX--put-electric-delete-selection
 #'LaTeX-insert-left-brace
 (lambda () (and LaTeX-electric-left-right-brace (not current-prefix-arg))))

(defun LaTeX-insert-corresponding-right-macro-and-brace
    (lmacro lbrace &optional optional prompt)
  "Insert right macro and brace correspoinding to LMACRO and LBRACE.
Left-right association is determined through
`LaTeX-left-right-macros-association' and `TeX-braces-association'.

If brace association can't be determined or `TeX-arg-right-insert-p'
is nil, consult user which brace should be used."
  ;; This function is called with LMACRO being one of the following
  ;; possibilities.
  ;;  (1) nil, which means LBRACE is isolated.
  ;;  (2) null string, which means LBRACE follows right after "\" to
  ;;      form "\(" or "\[".
  ;;  (3) a string in CARs of `LaTeX-left-right-macros-association'.
  (let ((rmacro (cdr (assoc lmacro LaTeX-left-right-macros-association)))
        (rbrace (cdr (assoc lbrace TeX-braces-association))))
    ;; Since braces like "\(" and "\)" should be paired, RMACRO
    ;; should be considered as null string in the case (2).
    (if (string= lmacro "")
        (setq rmacro ""))
    ;; Insert right macros such as "\right", "\bigr" etc., if necessary.
    ;; Even single "\" will be inserted so that "\)" or "\]" is
    ;; inserted after "\(", "\[".
    (if rmacro
        (insert TeX-esc rmacro))
    (cond
     ((and TeX-arg-right-insert-p rbrace)
      (insert rbrace))
     (rmacro
      (insert (completing-read
               (TeX-argument-prompt
                optional prompt
                (format "Which brace (default %s)"
                        (or rbrace ".")))
               TeX-left-right-braces
               nil nil nil nil (or rbrace ".")))))))

(defun LaTeX--find-preceding-left-macro-name ()
  "Return the left macro name just before the point, if any.
If the preceding macro isn't left macros such as \\left, \\bigl etc.,
return nil.
If the point is just after unescaped `TeX-esc', return the null string."
  ;; \left-!- => "left"
  ;; \-!- => ""
  ;; \infty-!- => nil
  ;; \&-!- => nil
  ;; \mathrm{abc}-!- => nil
  ;; {blah blah blah}-!- => nil
  ;; \\-!- => nil
  (let ((name (buffer-substring-no-properties
               (point)
               ;; This is only a helper function, so we do not
               ;; preserve point by save-excursion.
               (progn
                 ;; Assume left macro names consist of only A-Z and a-z.
                 (skip-chars-backward "A-Za-z")
                 (point)))))
    (if (and (TeX-escaped-p)
             (or (string= name "")
                 (assoc name LaTeX-left-right-macros-association)))
        name)))
(define-obsolete-function-alias
  'LaTeX-find-preceeding-left-macro-name
  #'LaTeX--find-preceding-left-macro-name "AUCTeX 12.2"
  "Compatibility function for typo in its name.")

(defcustom LaTeX-default-author 'user-full-name
  "Initial input to `LaTeX-arg-author' prompt.
If nil, do not prompt at all."
  :group 'LaTeX-macro
  :type '(choice (const :tag "User name in Emacs" user-full-name)
                 (const :tag "Do not prompt" nil)
                 string))

(defun LaTeX-arg-author (optional &optional prompt)
  "Prompt for author name.
Insert the given value as a TeX macro argument.  If OPTIONAL is
non-nil, insert it as an optional argument.  Use PROMPT as the
prompt string.  `LaTeX-default-author' is the initial input."
  (let ((author (if LaTeX-default-author
                    (TeX-read-string
                     (TeX-argument-prompt optional prompt "Author(s)")
                     (if (symbolp LaTeX-default-author)
                         (symbol-value LaTeX-default-author)
                       LaTeX-default-author))
                  "")))
    (TeX-argument-insert author optional nil)))

(defun TeX-read-key-val (optional key-val-alist &optional prompt complete
                                  predicate require-match
                                  initial-input hist def
                                  inherit-input-method)
  "Prompt for keys and values in KEY-VAL-ALIST and return them.
If OPTIONAL is non-nil, indicate in the prompt that we are
reading an optional argument.  KEY-VAL-ALIST can be
  - A function call without arguments
  - A function object
  - A symbol returning an alist
  - An alist

Each entry of this alist is a list.  The first element of each
list is a string representing a key and the optional second
element is a list with strings to be used as values for the key.
The second element can also be a variable returning a list of
strings.

PROMPT replaces the standard one where \\=' (k=v): \\=' is
appended to it.  If you want the full control over the prompt,
set COMPLETE to non-nil and then provide a full PROMPT.

PREDICATE, REQUIRE-MATCH, INITIAL-INPUT, HIST, DEF,
INHERIT-INPUT-METHOD are passed to `multi-prompt-key-value',
which see."
  (multi-prompt-key-value
   (TeX-argument-prompt optional
                        (cond ((and prompt (not complete))
                               (concat prompt " (k=v)"))
                              ((and prompt complete)
                               prompt)
                              (t nil))
                        "Options (k=v)"
                        complete)
   (cond ((and (listp key-val-alist)
               (symbolp (car key-val-alist))
               (fboundp (car key-val-alist))
               (not (eq (car key-val-alist) 'lambda)))
          (funcall (car key-val-alist)))
         ((functionp key-val-alist)
          (funcall key-val-alist))
         ((and (symbolp key-val-alist)
               (boundp key-val-alist))
          (symbol-value key-val-alist))
         ((and (listp key-val-alist)
               (listp (car key-val-alist)))
          key-val-alist)
         (t
          (error "Cannot interpret key-val-alist %S" key-val-alist)))
   predicate require-match initial-input hist def inherit-input-method))

(defun TeX-arg-key-val (optional key-val-alist &optional prompt complete
                                 rem-char leftbrace rightbrace
                                 predicate require-match
                                 initial-input hist def
                                 inherit-input-method)
  "Prompt for keys and values in KEY-VAL-ALIST.
Insert the given value as a TeX macro argument.  If OPTIONAL is
non-nil, insert it as an optional argument.  KEY-VAL-ALIST is an
alist.  The car of each element should be a string representing a
key and the optional cdr should be a list with strings to be used
as values for the key.  Refer to `TeX-read-key-val' for more
about KEY-VAL-ALIST.

PROMPT replaces the standard one where \\=' (k=v): \\=' is
appended to it.  If you want the full control over the prompt,
set COMPLETE to non-nil and then provide a full PROMPT.

REM-CHAR is a character removed from `crm-local-completion-map'
and `minibuffer-local-completion-map' when performing completion.
In most cases it will be ?\\s.

The brackets used are controlled by the string values of
LEFTBRACE and RIGHTBRACE.

PREDICATE, REQUIRE-MATCH, INITIAL-INPUT, HIST, DEF,
INHERIT-INPUT-METHOD are passed to `multi-prompt-key-value',
which see."
  (let ((TeX-arg-opening-brace (or leftbrace TeX-arg-opening-brace))
        (TeX-arg-closing-brace (or rightbrace TeX-arg-closing-brace))
        (crm-local-completion-map
         (if rem-char (remove (assoc rem-char crm-local-completion-map)
                              crm-local-completion-map)
           crm-local-completion-map))
        (minibuffer-local-completion-map
         (if rem-char (remove (assoc rem-char minibuffer-local-completion-map)
                              minibuffer-local-completion-map)
           minibuffer-local-completion-map)))
    (TeX-argument-insert
     (TeX-read-key-val optional key-val-alist prompt complete
                       predicate require-match initial-input
                       hist def inherit-input-method)
     optional)))

(defun TeX-read-completing-read (optional collection &optional prompt complete
                                          predicate require-match
                                          initial-input hist def
                                          inherit-input-method)
  "Read a string in the minibuffer, with completion and return it.
If OPTIONAL is non-nil, indicate it in the prompt.

COLLECTION provides elements for completion and is passed to
`completing-read'.  It can be:
  - A function call without arguments
  - A function object
  - A symbol returning a list
  - A List

PROMPT replaces the standard one where \\=' (cr): \\=' is appended to
it.  If you want the full control over the prompt, set COMPLETE
to non-nil and then provide a full PROMPT.

PREDICATE, REQUIRE-MATCH, INITIAL-INPUT, HIST, DEF and
INHERIT-INPUT-METHOD are passed to `completing-read', which see."
  (completing-read
   (TeX-argument-prompt optional
                        (cond ((and prompt (not complete))
                               (concat prompt " (cr)"))
                              ((and prompt complete)
                               prompt)
                              (t nil))
                        "Option (cr)"
                        complete)
   (cond ((and (listp collection)
               (symbolp (car collection))
               (fboundp (car collection))
               (not (eq (car collection) 'lambda)))
          (funcall (car collection)))
         ((functionp collection)
          (funcall collection))
         ((and (symbolp collection)
               (boundp collection))
          (symbol-value collection))
         (t collection))
   predicate require-match initial-input hist def inherit-input-method))

(defun TeX-arg-completing-read (optional collection &optional prompt complete
                                         prefix leftbrace rightbrace
                                         predicate require-match
                                         initial-input hist def
                                         inherit-input-method)
  "Read a string in the minibuffer, with completion and insert it.
If OPTIONAL is non-nil, indicate it in the minibuffer and insert
the result in brackets if not empty.  The brackets used are
controlled by the string values of LEFTBRACE and RIGHTBRACE.

For COLLECTION, PROMPT and COMPLETE, refer to `TeX-read-completing-read'.
For PREFIX, see `TeX-argument-insert'.
PREDICATE, REQUIRE-MATCH, INITIAL-INPUT, HIST, DEF and
INHERIT-INPUT-METHOD are passed to `completing-read', which see."
  (let ((TeX-arg-opening-brace (or leftbrace TeX-arg-opening-brace))
        (TeX-arg-closing-brace (or rightbrace TeX-arg-closing-brace)))
    (TeX-argument-insert
     (TeX-read-completing-read optional collection prompt complete
                               predicate require-match initial-input
                               hist def inherit-input-method)
     optional prefix)))

(defun TeX-read-completing-read-multiple (optional table &optional prompt complete
                                                   predicate require-match
                                                   initial-input hist def
                                                   inherit-input-method)
  "Read multiple strings in the minibuffer, with completion and return them.
If OPTIONAL is non-nil, indicate it in the prompt.

TABLE provides elements for completion and is passed to
`TeX-completing-read-multiple'.  It can be:
  - A function call without arguments
  - A function object
  - A symbol returning a list
  - A List

PROMPT replaces the standard one where \\=' (crm): \\=' is appended to
it.  If you want the full control over the prompt, set COMPLETE
to non-nil and then provide a full PROMPT.

PREDICATE, REQUIRE-MATCH, INITIAL-INPUT, HIST, DEF and
INHERIT-INPUT-METHOD are passed to
`TeX-completing-read-multiple', which see."
  (TeX-completing-read-multiple
   (TeX-argument-prompt optional
                        (cond ((and prompt (not complete))
                               (concat prompt " (crm)"))
                              ((and prompt complete)
                               prompt)
                              (t nil))
                        "Options (crm)"
                        complete)
   (cond ((and (listp table)
               (symbolp (car table))
               (fboundp (car table))
               (not (eq (car table) 'lambda)))
          (funcall (car table)))
         ((functionp table)
          (funcall table))
         ((and (symbolp table)
               (boundp table))
          (symbol-value table))
         (t table))
   predicate require-match initial-input hist def inherit-input-method))

(defun TeX-arg-completing-read-multiple (optional table &optional prompt complete
                                                  prefix crm-sep concat-sep
                                                  leftbrace rightbrace
                                                  predicate require-match
                                                  initial-input hist def
                                                  inherit-input-method)
  "Read multiple strings in the minibuffer, with completion and insert them.
If OPTIONAL is non-nil, indicate it in the minibuffer and insert
the result in brackets if not empty.

For TABLE, PROMPT and COMPLETE, see `TeX-read-completing-read-multiple'.

For PREFIX, see `TeX-argument-insert'.
CRM-SEP is a regexp which is bound locally to `crm-separator'.
CONCAT-SEP is a string which will be used to concat the queried
items, defaults to \",\".

The brackets used to insert the argument are controlled by the
string values of LEFTBRACE and RIGHTBRACE.

PREDICATE, REQUIRE-MATCH, INITIAL-INPUT, HIST, DEF and
INHERIT-INPUT-METHOD are passed to
`TeX-completing-read-multiple', which see."
  (let ((TeX-arg-opening-brace (or leftbrace TeX-arg-opening-brace))
        (TeX-arg-closing-brace (or rightbrace TeX-arg-closing-brace))
        (crm-separator (or crm-sep crm-separator))
        (concat-sep (or concat-sep ",")))
    (TeX-argument-insert
     (mapconcat #'identity
                (TeX-read-completing-read-multiple optional table prompt
                                                   complete predicate
                                                   require-match initial-input
                                                   hist def inherit-input-method)
                concat-sep)
     optional prefix)))

(defun TeX-read-hook ()
  "Read a LaTeX hook and return it as a string."
  (let* ((hook (completing-read
                (TeX-argument-prompt nil nil "Hook")
                '("cmd"
                  "env"
                  ;; From ltfilehook-doc.pdf
                  "file" "include" "class" "package"
                  ;; From lthooks-doc.pdf
                  "begindocument"  "enddocument"
                  "rmfamily"       "sffamily"
                  "ttfamily"       "normalfont"
                  "bfseries"       "mdseries"
                  ;; From ltshipout-doc.pdf
                  "shipout"
                  ;; From ltpara-doc.pdf
                  "para"
                  ;; From ltmarks-doc.pdf
                  "insertmark"
                  ;; From ltoutput.dtx
                  "build")))
         (place (lambda (&optional opt pr)
                  (completing-read
                   (TeX-argument-prompt opt pr "Where")
                   (cond ((member hook '("env" "para"))
                          '("after" "before" "begin" "end"))
                         ((string= hook "include")
                          '("after" "before" "end" "excluded"))
                         ((string= hook "begindocument")
                          '("before" "end"))
                         ((string= hook "enddocument")
                          '("afterlastpage" "afteraux" "info" "end"))
                         ((member hook '("bfseries" "mdseries"))
                          '("defaults"))
                         ((string= hook "shipout")
                          '("before"     "after"
                            "foreground" "background"
                            "firstpage"  "lastpage"))
                         (t
                          '("after" "before"))))))
         (search (lambda ()
                   (if (eq TeX-arg-input-file-search 'ask)
                       (not (y-or-n-p "Find file yourself? "))
                     TeX-arg-input-file-search)))
         name where files)
    (cond ((string= hook "cmd")
           ;; cmd/<name>/<where>: <where> is one of (before|after)
           (setq name (completing-read
                       (TeX-argument-prompt nil nil "Command")
                       (TeX-symbol-list)))
           (setq where (funcall place)))

          ;; env/<name>/<where>: <where> is one of (before|after|begin|end)
          ((string= hook "env")
           (setq name (completing-read
                       (TeX-argument-prompt nil nil "Environment")
                       (LaTeX-environment-list)))
           (setq where (funcall place)))

          ;; file/<file-name.xxx>/<where>: <file-name> is optional and
          ;; must be with extension and <where> is one of
          ;; (before|after)
          ((string= hook "file")
           (if (funcall search)
               (progn
                 (unless TeX-global-input-files-with-extension
                   (setq TeX-global-input-files-with-extension
                         (prog2
                             (message "Searching for files...")
                             (mapcar #'list
                                     (TeX-search-files-by-type 'texinputs
                                                               'global
                                                               t nil))
                           (message "Searching for files...done"))))
                 (setq name
                       (completing-read
                        (TeX-argument-prompt t nil "File")
                        TeX-global-input-files-with-extension)))
             (setq name
                   (file-name-nondirectory
                    (read-file-name
                     (TeX-argument-prompt t nil "File")
                     nil ""))))
           (setq where (funcall place)))

          ;; include/<file-name>/<where>: <file-name> is optional and
          ;; <where> is one of (before|after|end|excluded)
          ((string= hook "include")
           (if (funcall search)
               (progn
                 (setq files
                       (prog2
                           (message "Searching for files...")
                           ;; \include looks for files with TeX content,
                           ;; so limit the search:
                           (let* ((TeX-file-extensions '("tex" "ltx")))
                             (TeX-search-files-by-type 'texinputs 'local t t))
                         (message "Searching for files...done")))
                 (setq name (completing-read
                             (TeX-argument-prompt t nil "File")
                             files)))
             (setq name
                   (file-name-base
                    (read-file-name
                     (TeX-argument-prompt t nil "File")
                     nil ""))))
           (setq where (funcall place)))

          ;; class/<doc-class>/<where>: <doc-class> is optional and
          ;; <where> is one of (before|after)
          ((string= hook "class")
           (if (funcall search)
               (progn
                 (unless LaTeX-global-class-files
                   (setq LaTeX-global-class-files
                         (prog2
                             (message "Searching for LaTeX classes...")
                             (let* ((TeX-file-extensions '("cls")))
                               (mapcar #'list
                                       (TeX-search-files-by-type 'texinputs
                                                                 'global
                                                                 t t)))
                           (message "Searching for LaTeX classes...done"))))
                 (setq name (completing-read
                             (TeX-argument-prompt t nil "Document class")
                             LaTeX-global-class-files)))
             (setq name
                   (file-name-base
                    (read-file-name
                     (TeX-argument-prompt t nil "Document class")
                     nil ""))))
           (setq where (funcall place)))

          ;; package/<pack-name>/<where>: <pack-name> is optional and
          ;; <where> is one of (before|after)
          ((string= hook "package")
           (if (funcall search)
               (progn
                 (unless LaTeX-global-package-files
                   (setq LaTeX-global-package-files
                         (prog2
                             (message "Searching for LaTeX packages...")
                             (let* ((TeX-file-extensions '("sty")))
                               (mapcar #'list
                                       (TeX-search-files-by-type 'texinputs
                                                                 'global
                                                                 t t)))
                           (message "Searching for LaTeX packages...done"))))
                 (setq name (completing-read
                             (TeX-argument-prompt t nil "Package")
                             LaTeX-global-package-files)))
             (setq name (file-name-base
                         (read-file-name
                          (TeX-argument-prompt t nil "Package")
                          nil ""))))
           (setq where (funcall place)))

          ;; begindocument/<where>: <where> is empty or one of
          ;; (before|end)
          ((string= hook "begindocument")
           (setq where (funcall place t)))

          ;; enddocument/<where>: <where> is empty or one of
          ;; (afterlastpage|afteraux|info|end)
          ((string= hook "enddocument")
           (setq where (funcall place t)))

          ;; bfseries|mdseries/<where>: <where> is empty or defaults
          ((member hook '("bfseries" "mdseries"))
           (setq where (funcall place t)))

          ;; shipout/<where>: <where> is one of
          ;; (before|after|foreground|background|firstpage|lastpage)
          ((string= hook "shipout")
           (setq where (funcall place)))

          ;; build/<name>/<where>: <name> is one of (page|column) and
          ;; <where> is one of (before|after|(reset)?)
          ((string= hook "build")
           (setq name (completing-read
                       (TeX-argument-prompt nil nil "Place")
                       '("page" "column")))
           (setq where (if (string= name "page")
                           (completing-read
                            (TeX-argument-prompt nil nil "Where")
                            '("after" "before" "reset"))
                         (funcall place))))

          ;; Other hooks or user specific input, do nothing:
          (t nil))

    ;; Process the input: Concat the given parts and return it
    (concat hook
            (when (and name (not (string= name "")))
              (concat "/" name))
            (when (and where (not (string= where "")))
              (concat "/" where)))))

(defun TeX-arg-hook (optional)
  "Prompt for a LaTeX hook.
Insert the given hook as a TeX macro argument.  If OPTIONAL is
non-nil, insert it as an optional argument."
  (TeX-argument-insert (TeX-read-hook) optional))

;;; Verbatim constructs

(defcustom LaTeX-verbatim-macros-with-delims
  '("verb" "verb*")
  "Macros for inline verbatim with arguments in delimiters, like \\foo|...|.

Programs should not use this variable directly but the function
`LaTeX-verbatim-macros-with-delims' which returns a value
including buffer-local keyword additions via
`LaTeX-verbatim-macros-with-delims-local' as well."
  :group 'LaTeX-macro
  :type '(repeat (string)))

(defvar-local LaTeX-verbatim-macros-with-delims-local nil
  "Buffer-local variable for inline verbatim with args in delimiters.

Style files should add constructs to this variable and not to
`LaTeX-verbatim-macros-with-delims'.

Programs should not use this variable directly but the function
`LaTeX-verbatim-macros-with-delims' which returns a value
including values of the variable
`LaTeX-verbatim-macros-with-delims' as well.

May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")
(put 'LaTeX-verbatim-macros-with-delims-local 'safe-local-variable
     #'TeX--list-of-string-p)

;; Add the variable to `TeX-normal-mode-reset-list':
(add-to-list 'TeX-normal-mode-reset-list
             'LaTeX-verbatim-macros-with-delims-local)

(defcustom LaTeX-verbatim-macros-with-braces nil
  "Macros for inline verbatim with arguments in braces, like \\foo{...}.

Programs should not use this variable directly but the function
`LaTeX-verbatim-macros-with-braces' which returns a value
including buffer-local keyword additions via
`LaTeX-verbatim-macros-with-braces-local' as well."
  :group 'LaTeX-macro
  :type '(repeat (string)))

(defvar-local LaTeX-verbatim-macros-with-braces-local nil
  "Buffer-local variable for inline verbatim with args in braces.

Style files should add constructs to this variable and not to
`LaTeX-verbatim-macros-with-braces'.

Programs should not use this variable directly but the function
`LaTeX-verbatim-macros-with-braces' which returns a value
including values of the variable
`LaTeX-verbatim-macros-with-braces' as well.

May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")
(put 'LaTeX-verbatim-macros-with-braces-local 'safe-local-variable
     #'TeX--list-of-string-p)

;; Add the variable to `TeX-normal-mode-reset-list':
(add-to-list 'TeX-normal-mode-reset-list
             'LaTeX-verbatim-macros-with-braces-local)

(defcustom LaTeX-verbatim-environments
  '("verbatim" "verbatim*" "filecontents" "filecontents*")
  "Verbatim environments.

Programs should not use this variable directly but the function
`LaTeX-verbatim-environments' which returns a value including
buffer-local keyword additions via
`LaTeX-verbatim-environments-local' as well."
  :group 'LaTeX-environment
  :type '(repeat (string)))

(defvar-local LaTeX-verbatim-environments-local nil
  "Buffer-local variable for verbatim environments.

Style files should add constructs to this variable and not to
`LaTeX-verbatim-environments'.

Programs should not use this variable directly but the function
`LaTeX-verbatim-environments' which returns a value including
values of the variable `LaTeX-verbatim-environments' as well.

May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")
(put 'LaTeX-verbatim-environments-local 'safe-local-variable
     #'TeX--list-of-string-p)

;; Add the variable to `TeX-normal-mode-reset-list':
(add-to-list 'TeX-normal-mode-reset-list
             'LaTeX-verbatim-environments-local)

(defun LaTeX-verbatim-macros-with-delims ()
  "Return list of verbatim macros with delimiters."
  (append LaTeX-verbatim-macros-with-delims
          LaTeX-verbatim-macros-with-delims-local))

(defun LaTeX-verbatim-macros-with-braces ()
  "Return list of verbatim macros with braces."
  (append LaTeX-verbatim-macros-with-braces
          LaTeX-verbatim-macros-with-braces-local))

(defun LaTeX-verbatim-environments ()
  "Return list of verbatim environments."
  (append LaTeX-verbatim-environments
          LaTeX-verbatim-environments-local))

(defun LaTeX-verbatim-macro-boundaries (&optional arg-only)
  "Return boundaries of verbatim macro containing point.
Boundaries are returned as a cons cell where the car is the macro
start and the cdr the macro end.

If optional argument ARG-ONLY is non-nil, return the inner region
of the macro argument as cons."
  (save-excursion
    (let ((orig (point))
          (verbatim-regexp (regexp-opt
                            (append (LaTeX-verbatim-macros-with-delims)
                                    (LaTeX-verbatim-macros-with-braces))
                            t)))
      ;; Search backwards for the macro start, unless we are facing one
      (if (looking-at (concat (regexp-quote TeX-esc) verbatim-regexp))
          (forward-char 1)
        (while (progn
                 (skip-chars-backward (concat "^" (regexp-quote TeX-esc))
                                      (line-beginning-position))
                 (if (or (bolp)
                         (looking-at verbatim-regexp))
                     ;; Terminate the loop.
                     nil
                   (forward-char -1)
                   ;; Continue the loop.
                   t))))
      ;; Search forward for the macro end, unless we failed to find a start
      (unless (bolp)
        (let* ((beg (1- (point)))
               (end (match-end 0))
               ;; XXX: Here we assume we are dealing with \verb which
               ;; expects the delimiter right behind the command.
               ;; However, \lstinline can also cope with whitespace as
               ;; well as an optional argument after the command.
               ;; \Verb (from fancyvrb) also accepts an optional
               ;; argument which we have to encounter.  We assume that
               ;; users don't write something like this '\Verb[foo['
               ;; and again the delimiter is directly after the ]
               ;; closing the optional argument:
               (delimiter (progn
                            (if (= (char-after end) (aref LaTeX-optop 0))
                                ;; Update `end'.
                                (save-excursion (goto-char end)
                                                (forward-list)
                                                (setq end (point))))
                            (string (char-after end)))))
          ;; Heuristic: If an opening brace is encountered, search for
          ;; a closing brace as an end marker.
          ;; Like that the function should work for \verb|...| as well
          ;; as for \url{...}.
          (if (string= delimiter TeX-grop)
              (progn
                (goto-char end)
                ;; Allow one level of nested braces as verb argument.
                (re-search-forward "{[^}{]*\\(?:{[^}{]*}[^}{]*\\)*}"
                                   (line-end-position) t)
                (backward-char))
            (goto-char (1+ end))
            (skip-chars-forward (concat "^" delimiter) (line-end-position)))
          (when (<= orig (point))
            (if arg-only
                (cons (1+ end) (point))
              (cons beg (1+ (point))))))))))

;; Currently, AUCTeX doesn't use this function at all.  We leave it as
;; a utility function.  It was originally used in `LaTeX-verbatim-p'.
(defun LaTeX-current-verbatim-macro ()
  "Return name of verbatim macro containing point, nil if none is present."
  (let ((macro-boundaries (LaTeX-verbatim-macro-boundaries)))
    (when macro-boundaries
      (save-excursion
        (goto-char (car macro-boundaries))
        (forward-char (length TeX-esc))
        (buffer-substring-no-properties
         (point) (progn (skip-chars-forward "@A-Za-z*") (point)))))))

(defun LaTeX-verbatim-p (&optional pos)
  "Return non-nil if position POS is in a verbatim-like construct.
The macro body (\"\\verb\") and its delimiters, including
optional argument if any, aren't considered as component of a
verbatim-like construct."
  (save-excursion
    (when pos (goto-char pos))
    (save-match-data
      ;; TODO: Factor out syntax propertize facility from font-latex.el
      ;; and re-implement as major mode feature.  Then we can drop the
      ;; fallback code below.
      (if (eq TeX-install-font-lock 'font-latex-setup)
          (progn
            (syntax-propertize (point))
            (nth 3 (syntax-ppss)))
        ;; Fallback for users who stay away from font-latex.
        (or
         (let ((region (LaTeX-verbatim-macro-boundaries t)))
           (and region
                (<= (car region) (point) (cdr region))))
         (member (LaTeX-current-environment) (LaTeX-verbatim-environments)))))))


;;; Formatting

(defcustom LaTeX-syntactic-comments t
  "If non-nil comments will be handled according to LaTeX syntax.
This variable influences, among others, the behavior of
indentation and filling which will take LaTeX syntax into
consideration just as is in the non-commented source code."
  :type 'boolean
  :group 'LaTeX)


;;; Indentation

;; We are distinguishing two different types of comments:
;;
;; 1) Comments starting in column one (line comments)
;;
;; 2) Comments starting after column one with only whitespace
;;    preceding it.
;;
;; (There is actually a third type: Comments preceded not only by
;; whitespace but by some code as well; so-called code comments.  But
;; they are not relevant for the following explanations.)
;;
;; Additionally we are distinguishing two different types of
;; indentation:
;;
;; a) Outer indentation: Indentation before the comment character(s).
;;
;; b) Inner indentation: Indentation after the comment character(s)
;;    (taking into account possible comment padding).
;;
;; Comments can be filled syntax-aware or not.
;;
;; In `docTeX-mode' line comments should always be indented
;; syntax-aware and the comment character has to be anchored at the
;; first column (unless the appear in a macrocode environment).  Other
;; comments not in the documentation parts always start after the
;; first column and can be indented syntax-aware or not.  If they are
;; indented syntax-aware both the indentation before and after the
;; comment character(s) have to be checked and adjusted.  Indentation
;; should not move the comment character(s) to the first column.  With
;; `LaTeX-syntactic-comments' disabled, line comments should still be
;; indented syntax-aware.
;;
;; In `LaTeX-mode' comments starting in different columns don't have
;; to be handled differently.  They don't have to be anchored in
;; column one.  That means that in any case indentation before and
;; after the comment characters has to be checked and adjusted.

(defgroup LaTeX-indentation nil
  "Indentation of LaTeX code in AUCTeX"
  :group 'LaTeX
  :group 'TeX-indentation)

(defcustom LaTeX-indent-level 2
  "Indentation of begin-end blocks in LaTeX."
  :group 'LaTeX-indentation
  :type 'integer)

(defcustom LaTeX-item-indent (- LaTeX-indent-level)
  "Extra indentation for lines beginning with an item."
  :group 'LaTeX-indentation
  :type 'integer)

(defcustom LaTeX-item-regexp "\\(bib\\)?item\\b"
  "Regular expression matching macros considered items."
  :group 'LaTeX-indentation
  :type 'regexp)

(defcustom LaTeX-indent-environment-list
  '(("verbatim"      current-indentation)
    ("verbatim*"     current-indentation)
    ("filecontents"  current-indentation)
    ("filecontents*" current-indentation)
    ("tabular"       LaTeX-indent-tabular)
    ("tabular*"      LaTeX-indent-tabular)
    ("array"         LaTeX-indent-tabular)
    ("eqnarray"      LaTeX-indent-tabular)
    ("eqnarray*"     LaTeX-indent-tabular)
    ;; envs of amsmath.sty
    ("align"       LaTeX-indent-tabular)
    ("align*"      LaTeX-indent-tabular)
    ("aligned"     LaTeX-indent-tabular)
    ("alignat"     LaTeX-indent-tabular)
    ("alignat*"    LaTeX-indent-tabular)
    ("alignedat"   LaTeX-indent-tabular)
    ("xalignat"    LaTeX-indent-tabular)
    ("xalignat*"   LaTeX-indent-tabular)
    ("xxalignat"   LaTeX-indent-tabular)
    ("flalign"     LaTeX-indent-tabular)
    ("flalign*"    LaTeX-indent-tabular)
    ("split"       LaTeX-indent-tabular)
    ("matrix"      LaTeX-indent-tabular)
    ("pmatrix"     LaTeX-indent-tabular)
    ("bmatrix"     LaTeX-indent-tabular)
    ("Bmatrix"     LaTeX-indent-tabular)
    ("vmatrix"     LaTeX-indent-tabular)
    ("Vmatrix"     LaTeX-indent-tabular)
    ("smallmatrix" LaTeX-indent-tabular)
    ("cases"       LaTeX-indent-tabular)
    ;; env of longtable.sty
    ("longtable" LaTeX-indent-tabular)
    ;; env of ltcaption.sty
    ("longtable*" LaTeX-indent-tabular)
    ;; envs of mathtools.sty
    ("matrix*"       LaTeX-indent-tabular)
    ("pmatrix*"      LaTeX-indent-tabular)
    ("bmatrix*"      LaTeX-indent-tabular)
    ("Bmatrix*"      LaTeX-indent-tabular)
    ("vmatrix*"      LaTeX-indent-tabular)
    ("Vmatrix*"      LaTeX-indent-tabular)
    ("smallmatrix*"  LaTeX-indent-tabular)
    ("psmallmatrix"  LaTeX-indent-tabular)
    ("psmallmatrix*" LaTeX-indent-tabular)
    ("bsmallmatrix"  LaTeX-indent-tabular)
    ("bsmallmatrix*" LaTeX-indent-tabular)
    ("vsmallmatrix"  LaTeX-indent-tabular)
    ("vsmallmatrix*" LaTeX-indent-tabular)
    ("Vsmallmatrix"  LaTeX-indent-tabular)
    ("Vsmallmatrix*" LaTeX-indent-tabular)
    ("dcases"        LaTeX-indent-tabular)
    ("dcases*"       LaTeX-indent-tabular)
    ("rcases"        LaTeX-indent-tabular)
    ("rcases*"       LaTeX-indent-tabular)
    ("drcases"       LaTeX-indent-tabular)
    ("drcases*"      LaTeX-indent-tabular)
    ("cases*"        LaTeX-indent-tabular)
    ;; envs of stabular.sty
    ("stabular"  LaTeX-indent-tabular)
    ("stabular*" LaTeX-indent-tabular)
    ;; envs of supertabular.sty
    ("supertabular"    LaTeX-indent-tabular)
    ("supertabular*"   LaTeX-indent-tabular)
    ("mpsupertabular"  LaTeX-indent-tabular)
    ("mpsupertabular*" LaTeX-indent-tabular)
    ;; envs of tabularray.sty
    ("tblr"     LaTeX-indent-tabular)
    ("longtblr" LaTeX-indent-tabular)
    ("talltblr" LaTeX-indent-tabular)
    ("booktabs" LaTeX-indent-tabular)
    ("+array"   LaTeX-indent-tabular)
    ("+matrix"  LaTeX-indent-tabular)
    ("+bmatrix" LaTeX-indent-tabular)
    ("+Bmatrix" LaTeX-indent-tabular)
    ("+pmatrix" LaTeX-indent-tabular)
    ("+vmatrix" LaTeX-indent-tabular)
    ("+Vmatrix" LaTeX-indent-tabular)
    ("+cases"   LaTeX-indent-tabular)
    ;; env from tabularx.sty
    ("tabularx" LaTeX-indent-tabular)
    ;; env from tabulary.sty
    ("tabulary" LaTeX-indent-tabular)
    ;; env from xltabular.sty
    ("xltabular" LaTeX-indent-tabular)
    ;; envs of xtab.sty
    ("xtabular"    LaTeX-indent-tabular)
    ("xtabular*"   LaTeX-indent-tabular)
    ("mpxtabular"  LaTeX-indent-tabular)
    ("mpxtabular*" LaTeX-indent-tabular)
    ;; The following should have their own, smart indentation function.
    ;; Some other day.
    ("displaymath")
    ("equation")
    ("picture")
    ("tabbing")
    ;; envs from amsmath.sty
    ("gather") ("gather*") ("gathered")
    ("equation*") ("multline") ("multline*")
    ;; envs from doc.sty
    ("macrocode") ("macrocode*"))
  "Alist of environments with special indentation.
The second element in each entry is the function to calculate the
indentation level in columns.

Environments present in this list are not filled by filling
functions, see `LaTeX-fill-region-as-paragraph'."
  :group 'LaTeX-indentation
  :type '(repeat (list (string :tag "Environment")
                       (option function)))
  :package-version '(auctex . "14.0.7"))

(defcustom LaTeX-indent-environment-check t
  "If non-nil, check for any special environments."
  :group 'LaTeX-indentation
  :type 'boolean)

(defcustom LaTeX-document-regexp "document"
  "Regexp matching environments in which the indentation starts at col 0."
  :group 'LaTeX-indentation
  :type 'regexp)

(defcustom LaTeX-begin-regexp "begin\\b\\|\\["
  "Regexp matching macros considered begins."
  :group 'LaTeX-indentation
  :type 'regexp)

(defcustom LaTeX-end-regexp "end\\b\\|\\]"
  "Regexp matching macros considered ends."
  :group 'LaTeX-indentation
  :type 'regexp)

(defcustom LaTeX-left-right-indent-level LaTeX-indent-level
  "The level of indentation produced by a \\left macro."
  :group 'LaTeX-indentation
  :type 'integer)

(defcustom LaTeX-indent-comment-start-regexp "%"
  "Regexp matching comments ending the indent level count.
This means, we just count the LaTeX tokens \\left, \\right, \\begin,
and \\end up to the first occurence of text matching this regexp.
Thus, the default \"%\" stops counting the tokens at a comment.  A
value of \"%[^>]\" would allow you to alter the indentation with
comments, for example with comment `%> \\begin'.
Lines which start with `%' are not considered at all, regardless of this
value."
  :group 'LaTeX-indentation
  :type 'regexp)

(defvar docTeX-indent-inner-fixed
  `((,(concat (regexp-quote TeX-esc)
              "\\(begin\\|end\\)[ \t]*{macrocode\\*?}")
     4 t)
    (,(concat (regexp-quote TeX-esc)
              "\\(begin\\|end\\)[ \t]*{\\(macro\\|environment\\)\\*?}")
     0 nil)
    (,(concat (regexp-quote TeX-esc)
              "\\(begin\\|end\\)[ \t]*{verbatim\\*?}")
     0 t))
  "List of items which should have a fixed inner indentation.
The items consist of three parts.  The first is a regular
expression which should match the respective string.  The second
is the amount of spaces to be used for indentation.  The third
toggles if comment padding is relevant or not.  If t padding is
part of the amount given, if nil the amount of spaces will be
inserted after potential padding.")

(defvar-local LaTeX-indent-begin-list nil
  "List of macros increasing indentation.
Each item in this list is a string with the name of the macro
without a backslash.  The final regexp will be calculated by the
function `LaTeX-indent-commands-regexp-make'.  A regexp for the
\\if contructs is added by the function as well.  AUCTeX styles
should add their macros to this variable and then run
`LaTeX-indent-commands-regexp-make'.")

(defvar-local LaTeX-indent-begin-exceptions-list nil
  "List of macros which shouldn't increase the indentation.
Each item in this list is a string without a backslash and will
mostly start with \"if\".  These macros should not increase
indentation although they start with \"if\", for example the
\"ifthenelse\" macro provided by the ifthen package.  AUCTeX
styles should add their macros to this variable and then run
`LaTeX-indent-commands-regexp-make'.")

(defvar-local LaTeX-indent-mid-list nil
  "List of macros which backindent the line where they appear.
Each item in this list is a string with the name of the macro
without a backslash.  The final regexp will be calculated by the
function `LaTeX-indent-commands-regexp-make' which takes care of
\\else and \\or.  AUCTeX styles should add their macros to this
variable and then run `LaTeX-indent-commands-regexp-make'.")

(defvar-local LaTeX-indent-end-list nil
  "List of macros decreasing indentation.
Each item in this list is a string with the name of the macro
without a backslash.  The final regexp will be calculated by the
function `LaTeX-indent-commands-regexp-make' which takes care of
\\fi.  AUCTeX styles should add their macros to this variable and
then run `LaTeX-indent-commands-regexp-make'.")

(defvar-local LaTeX-indent-begin-regexp-local nil
  "Regexp calculated from `LaTeX-indent-begin-list'.
The value is calculated and set by the function
`LaTeX-indent-commands-regexp-make' which already takes care of
\\if constructs.")

(defvar-local LaTeX-indent-begin-regexp-exceptions-local nil
  "Regexp calculated from `LaTeX-indent-begin-exceptions-list'.
The value is calculated and set by the function
`LaTeX-indent-commands-regexp-make' which already takes care of
\\ifthenelse.")

(defvar-local LaTeX-indent-mid-regexp-local nil
  "Regexp calculated from `LaTeX-indent-mid-list'.
The value is calculated and set by the function
`LaTeX-indent-commands-regexp-make' which already takes care of
\\else and \\or.")

(defvar-local LaTeX-indent-end-regexp-local nil
  "Regexp calculated from `LaTeX-indent-end-list'.
The value is calculated and set by the function
`LaTeX-indent-commands-regexp-make' which already takes care of
\\fi.")

(defun LaTeX-indent-commands-regexp-make ()
  "Calculate final regexp for adjusting indentation.
This function takes the elements provided in
`LaTeX-indent-begin-list', `LaTeX-indent-begin-exceptions-list',
`LaTeX-indent-mid-list' and `LaTeX-indent-end-list' and generates
the regexp's which are stored in
`LaTeX-indent-begin-regexp-local',
`LaTeX-indent-begin-regexp-exceptions-local',
`LaTeX-indent-mid-regexp-local' and
`LaTeX-indent-end-regexp-local' accordingly.  Some standard
macros are added to the regexp's.  This function is called in
`LaTeX-mode-cleanup' to set the regexp's."
  (let* (cmds
         symbs
         (func (lambda (in regexp out)
                 (setq cmds nil
                       symbs nil)
                 (dolist (elt in)
                   (if (string-match "[^a-zA-Z@]" elt)
                       (push elt symbs)
                     (push elt cmds)))
                 (set out (concat regexp
                                  (when cmds
                                    (concat "\\|"
                                            (regexp-opt cmds)
                                            "\\b"))
                                  (when symbs
                                    (concat "\\|"
                                            (regexp-opt symbs))))))))
    (funcall func
             LaTeX-indent-begin-list
             "if[a-zA-Z@:_]*\\b"
             'LaTeX-indent-begin-regexp-local)
    (funcall func
             LaTeX-indent-mid-list
             "else:?\\b\\|or\\b"
             'LaTeX-indent-mid-regexp-local)
    (funcall func
             LaTeX-indent-end-list
             "fi:?\\b\\|repeat\\b"
             'LaTeX-indent-end-regexp-local)
    (funcall func
             LaTeX-indent-begin-exceptions-list
             "ifthenelse\\b\\|iff\\b"
             'LaTeX-indent-begin-regexp-exceptions-local)))

(defun LaTeX-indent-line ()
  "Indent the line containing point, as LaTeX source.
Add `LaTeX-indent-level' indentation in each \\begin{ - \\end{ block.
Lines starting with an item is given an extra indentation of
`LaTeX-item-indent'."
  (interactive)
  (let* ((case-fold-search nil)
         ;; Compute a fill prefix.  Whitespace after the comment
         ;; characters will be disregarded and replaced by
         ;; `comment-padding'.
         (fill-prefix
          (and (TeX-in-commented-line)
               (save-excursion
                 (beginning-of-line)
                 (looking-at
                  (concat "\\([ \t]*" TeX-comment-start-regexp "+\\)+"))
                 (concat (match-string 0) (TeX-comment-padding-string))))))
    (save-excursion
      (cond ((and fill-prefix
                  (eq major-mode 'docTeX-mode)
                  (TeX-in-line-comment))
             ;; If point is in a line comment in `docTeX-mode' we only
             ;; consider the inner indentation.  An exception is when
             ;; we're inside a verbatim environment where we don't
             ;; want to touch the indentation, notably with a
             ;; fill-prefix "% ":
             (unless (member (LaTeX-current-environment)
                             (LaTeX-verbatim-environments))
               (let ((inner-indent (LaTeX-indent-calculate 'inner)))
                 (when (/= (LaTeX-current-indentation 'inner) inner-indent)
                   (LaTeX-indent-inner-do inner-indent)))))
            ((and fill-prefix
                  LaTeX-syntactic-comments)
             ;; In any other case of a comment we have to consider
             ;; outer and inner indentation if we do syntax-aware
             ;; indentation.
             (let ((inner-indent (LaTeX-indent-calculate 'inner))
                   (outer-indent (LaTeX-indent-calculate 'outer)))
               (when (/= (LaTeX-current-indentation 'inner) inner-indent)
                 (LaTeX-indent-inner-do inner-indent))
               (when (/= (LaTeX-current-indentation 'outer) outer-indent)
                 (LaTeX-indent-outer-do outer-indent))))
            (t
             ;; The default is to adapt whitespace before any
             ;; non-whitespace character, i.e. to do outer
             ;; indentation.
             (let ((outer-indent (LaTeX-indent-calculate 'outer)))
               (when (/= (LaTeX-current-indentation 'outer) outer-indent)
                 (LaTeX-indent-outer-do outer-indent))))))
    (when (< (current-column) (save-excursion
                                (LaTeX-back-to-indentation) (current-column)))
      (LaTeX-back-to-indentation))))

(defun LaTeX-indent-inner-do (inner-indent)
  ;; Small helper function for `LaTeX-indent-line' to perform
  ;; indentation after a comment character.  It requires that
  ;; `LaTeX-indent-line' already set the appropriate variables and
  ;; should not be used outside of `LaTeX-indent-line'.
  (move-to-left-margin)
  (TeX-re-search-forward-unescaped
   (concat "\\(" TeX-comment-start-regexp "+[ \t]*\\)+") (line-end-position) t)
  (delete-region (line-beginning-position) (point))
  (insert fill-prefix)
  (indent-to (+ inner-indent (length fill-prefix))))

(defun LaTeX-indent-outer-do (outer-indent)
  ;; Small helper function for `LaTeX-indent-line' to perform
  ;; indentation of normal lines or before a comment character in a
  ;; commented line.  It requires that `LaTeX-indent-line' already set
  ;; the appropriate variables and should not be used outside of
  ;; `LaTeX-indent-line'.
  (back-to-indentation)
  (delete-region (line-beginning-position) (point))
  (indent-to outer-indent))

(defun LaTeX-verbatim-regexp (&optional comment)
  "Calculate the verbatim env regex from `LaTeX-verbatim-environments'.
If optional argument COMMENT is non-nil, include comment env from
`LaTeX-comment-env-list'."
  (regexp-opt (append (LaTeX-verbatim-environments)
                      (if comment LaTeX-comment-env-list))))

(defun LaTeX-indent-calculate (&optional force-type)
  "Return the indentation of a line of LaTeX source.
FORCE-TYPE can be used to force the calculation of an inner or
outer indentation in case of a commented line.  The symbols
`inner' and `outer' are recognized."
  (save-excursion
    (LaTeX-back-to-indentation force-type)
    (let ((i 0)
          (list-length (safe-length docTeX-indent-inner-fixed))
          (case-fold-search nil)
          entry
          found)
      (cond ((save-excursion (beginning-of-line) (bobp)) 0)
            ((and (eq major-mode 'docTeX-mode)
                  fill-prefix
                  (TeX-in-line-comment)
                  (progn
                    (while (and (< i list-length)
                                (not found))
                      (setq entry (nth i docTeX-indent-inner-fixed))
                      (when (looking-at (nth 0 entry))
                        (setq found t))
                      (setq i (1+ i)))
                    found))
             (if (nth 2 entry)
                 (- (nth 1 entry) (if (integerp comment-padding)
                                      comment-padding
                                    (length comment-padding)))
               (nth 1 entry)))
            ((looking-at (concat (regexp-quote TeX-esc)
                                 "\\(begin\\|end\\){"
                                 (LaTeX-verbatim-regexp t)
                                 "}"))
             ;; \end{verbatim} must be flush left, otherwise an unwanted
             ;; empty line appears in LaTeX's output.
             0)
            ((and LaTeX-indent-environment-check
                  ;; Special environments.
                  (let ((entry (assoc (or LaTeX-current-environment
                                          (LaTeX-current-environment))
                                      LaTeX-indent-environment-list)))
                    (and entry
                         (nth 1 entry)
                         (funcall (nth 1 entry))))))
            ((looking-at (concat (regexp-quote TeX-esc)
                                 "\\("
                                 LaTeX-end-regexp
                                 "\\)"))
             ;; Backindent at \end.
             (- (LaTeX-indent-calculate-last force-type) LaTeX-indent-level))
            ((looking-at (concat (regexp-quote TeX-esc) "right\\b"))
             ;; Backindent at \right.
             (- (LaTeX-indent-calculate-last force-type)
                LaTeX-left-right-indent-level))
            ((looking-at (concat (regexp-quote TeX-esc)
                                 "\\("
                                 LaTeX-item-regexp
                                 "\\)"))
             ;; Items.
             (+ (LaTeX-indent-calculate-last force-type) LaTeX-item-indent))
            ;; Other (La)TeX programming constructs which end
            ;; something, \fi for example where we backindent:
            ((looking-at (concat (regexp-quote TeX-esc)
                                 "\\("
                                 LaTeX-indent-end-regexp-local
                                 "\\)"))
             (- (LaTeX-indent-calculate-last force-type) LaTeX-indent-level))
            ;; (La)TeX programming contructs which backindent only the
            ;; current line, for example \or or \else where we backindent:
            ((looking-at (concat (regexp-quote TeX-esc)
                                 "\\("
                                 LaTeX-indent-mid-regexp-local
                                 "\\)"))
             (- (LaTeX-indent-calculate-last force-type) LaTeX-indent-level))
            ((memq (char-after) (append
                                 TeX-indent-close-delimiters '(?\})))
             ;; End brace in the start of the line.
             (- (LaTeX-indent-calculate-last force-type)
                TeX-brace-indent-level))
            (t (LaTeX-indent-calculate-last force-type))))))

(defun LaTeX-indent-level-count ()
  "Count indentation change caused by macros in the current line.
Macros contain \\left, \\right, \\begin, \\end and \\if-\\fi
constructs.  A special case is \\newif where the following
\\if<foo> should not change the indentation."
  (save-excursion
    (save-restriction
      (let ((count 0))
        (narrow-to-region (point)
                          (save-excursion
                            (re-search-forward
                             (concat "[^" TeX-esc "]"
                                     "\\(" LaTeX-indent-comment-start-regexp
                                     "\\)\\|\n\\|\\'"))
                            (backward-char)
                            (point)))
        (while (search-forward TeX-esc nil t)
          (cond
           ((looking-at "left\\b")
            (setq count (+ count LaTeX-left-right-indent-level)))
           ((looking-at "right\\b")
            (setq count (- count LaTeX-left-right-indent-level)))
           ((looking-at LaTeX-begin-regexp)
            (setq count (+ count LaTeX-indent-level)))
           ((looking-at LaTeX-end-regexp)
            (setq count (- count LaTeX-indent-level)))
           ((looking-at "newif\\b")
            (search-forward TeX-esc (line-end-position) t))
           ((and (not (looking-at LaTeX-indent-begin-regexp-exceptions-local))
                 (looking-at LaTeX-indent-begin-regexp-local))
            (setq count (+ count LaTeX-indent-level)))
           ((looking-at LaTeX-indent-end-regexp-local)
            (setq count (- count LaTeX-indent-level)))
           ((looking-at (regexp-quote TeX-esc))
            (forward-char 1))))
        count))))

(defun LaTeX-indent-calculate-last (&optional force-type)
  "Return the correct indentation of a normal line of text.
The point is supposed to be at the beginning of the current line.
FORCE-TYPE can be used to force the calculation of an inner or
outer indentation in case of a commented line.  The symbols
`inner' and `outer' are recognized."
  (let (line-comment-current-flag
        line-comment-last-flag
        comment-current-flag
        comment-last-flag
        (indent-across-comments (or docTeX-indent-across-comments
                                    (not (eq major-mode 'docTeX-mode)))))
    (beginning-of-line)
    (setq line-comment-current-flag (TeX-in-line-comment)
          comment-current-flag (TeX-in-commented-line))
    (if comment-current-flag
        (skip-chars-backward "%\n\t ")
      (skip-chars-backward "\n\t "))
    (beginning-of-line)
    ;; If we are called in a non-comment line, skip over comment
    ;; lines.  The computation of indentation should in this case
    ;; rather take the last non-comment line into account.
    ;; Otherwise there might arise problems with e.g. multi-line
    ;; code comments.  This behavior can be disabled in docTeX mode
    ;; where large amounts of line comments may have to be skipped
    ;; and indentation should not be influenced by unrelated code in
    ;; other macrocode environments.
    (while (and indent-across-comments
                (not comment-current-flag)
                (TeX-in-commented-line)
                (not (bobp)))
      (skip-chars-backward "\n\t ")
      (beginning-of-line))
    (setq line-comment-last-flag (TeX-in-line-comment)
          comment-last-flag (TeX-in-commented-line))
    (LaTeX-back-to-indentation force-type)
    ;; Separate line comments and other stuff (normal text/code and
    ;; code comments).  Additionally we don't want to compute inner
    ;; indentation when a commented and a non-commented line are
    ;; compared.
    (cond ((or (and (eq major-mode 'docTeX-mode)
                    (or (and line-comment-current-flag
                             (not line-comment-last-flag))
                        (and (not line-comment-current-flag)
                             line-comment-last-flag)))
               (and force-type
                    (eq force-type 'inner)
                    (or (and comment-current-flag
                             (not comment-last-flag))
                        (and (not comment-current-flag)
                             comment-last-flag))))
           0)
          ((looking-at (concat (regexp-quote TeX-esc)
                               "begin *{\\("
                               LaTeX-document-regexp
                               "\\)}"))
           ;; I dislike having all of the document indented...
           (+ (LaTeX-current-indentation force-type)
              ;; Some people have opening braces at the end of the
              ;; line, e.g. in case of `\begin{letter}{%'.
              (TeX-brace-count-line)))
          ((and (eq major-mode 'docTeX-mode)
                (looking-at (concat (regexp-quote TeX-esc)
                                    "end[ \t]*{macrocode\\*?}"))
                fill-prefix
                (TeX-in-line-comment))
           ;; Reset indentation to zero after a macrocode environment
           ;; only when we're not still inside a describing
           ;; environment like "macro" or "environment" etc.  Text
           ;; inside these environments after '\end{macrocode}' is
           ;; indented with `LaTeX-indent-level':
           (let ((outer-env (LaTeX-current-environment 2)))
             (cond ((member outer-env '("macro" "environment"))
                    LaTeX-indent-level)
                   ((and (fboundp 'LaTeX-doc-NewDocElement-list)
                         (LaTeX-doc-NewDocElement-list)
                         (member outer-env
                                 (mapcar #'cadr (LaTeX-doc-NewDocElement-list))))
                    LaTeX-indent-level)
                   (t 0))))
          ((looking-at (concat (regexp-quote TeX-esc)
                               "begin *{"
                               ;; Don't give optional argument here
                               ;; because indent would be disabled
                               ;; inside comment env otherwise.
                               (LaTeX-verbatim-regexp)
                               "}"))
           0)
          ((looking-at (concat (regexp-quote TeX-esc)
                               "end *{"
                               (LaTeX-verbatim-regexp t)
                               "}"))
           ;; If I see an \end{verbatim} in the previous line I skip
           ;; back to the preceding \begin{verbatim}.
           (save-excursion
             (if (re-search-backward (concat (regexp-quote TeX-esc)
                                             "begin *{"
                                             (LaTeX-verbatim-regexp t)
                                             "}") 0 t)
                 (LaTeX-indent-calculate-last force-type)
               0)))
          (t (+ (LaTeX-current-indentation force-type)
                (if (not (and force-type
                              (eq force-type 'outer)
                              (TeX-in-commented-line)))
                    (+ (LaTeX-indent-level-count)
                       (TeX-brace-count-line))
                  0)
                (cond ((looking-at (concat (regexp-quote TeX-esc)
                                           "\\("
                                           LaTeX-end-regexp
                                           "\\)"))
                       LaTeX-indent-level)
                      ((looking-at
                        (concat (regexp-quote TeX-esc) "right\\b"))
                       LaTeX-left-right-indent-level)
                      ((looking-at (concat (regexp-quote TeX-esc)
                                           "\\("
                                           LaTeX-item-regexp
                                           "\\)"))
                       (- LaTeX-item-indent))
                      ((looking-at (concat (regexp-quote TeX-esc)
                                           "\\("
                                           LaTeX-indent-end-regexp-local
                                           "\\)"))
                       LaTeX-indent-level)
                      ((looking-at (concat (regexp-quote TeX-esc)
                                           "\\("
                                           LaTeX-indent-mid-regexp-local
                                           "\\)"))
                       LaTeX-indent-level)
                      ((memq (char-after) (append
                                           TeX-indent-close-delimiters
                                           '(?\})))
                       TeX-brace-indent-level)
                      (t 0)))))))

(defun LaTeX-current-indentation (&optional force-type)
  "Return the indentation of a line.
FORCE-TYPE can be used to force the calculation of an inner or
outer indentation in case of a commented line.  The symbols
`inner' and `outer' are recognized."
  (if (and fill-prefix
           (or (and force-type
                    (eq force-type 'inner))
               (and (not force-type)
                    (or
                     ;; If `LaTeX-syntactic-comments' is not enabled,
                     ;; do conventional indentation
                     LaTeX-syntactic-comments
                     ;; Line comments in `docTeX-mode' are always
                     ;; indented syntax-aware so we need their inner
                     ;; indentation.
                     (and (TeX-in-line-comment)
                          (eq major-mode 'docTeX-mode))))))
      ;; INNER indentation
      (save-excursion
        (beginning-of-line)
        (looking-at (concat "\\(?:[ \t]*" TeX-comment-start-regexp "+\\)+"
                            "\\([ \t]*\\)"))
        (- (length (match-string 1)) (length (TeX-comment-padding-string))))
    ;; OUTER indentation
    (current-indentation)))

(defun LaTeX-back-to-indentation (&optional force-type)
  "Move point to the first non-whitespace character on this line.
If it is commented and comments are formatted syntax-aware move
point to the first non-whitespace character after the comment
character(s), but only if `this-command' is not a newline
command, that is, `TeX-newline' or the value of
`TeX-newline-function'.  The optional argument FORCE-TYPE can be
used to force point being moved to the inner or outer indentation
in case of a commented line.  The symbols `inner' and `outer' are
recognized."
  (if (or (and force-type
               (eq force-type 'inner))
          (and (not force-type)
               (or (and (TeX-in-line-comment)
                        (eq major-mode 'docTeX-mode))
                   (and (TeX-in-commented-line)
                        ;; Only move after the % if we're not
                        ;; performing a newline command (bug#47757).
                        (not (memq this-command
                                   `( TeX-newline
                                      ,TeX-newline-function)))
                        LaTeX-syntactic-comments))))
      (progn
        (beginning-of-line)
        ;; Should this be anchored at the start of the line?
        (TeX-re-search-forward-unescaped
         (concat "\\(?:" TeX-comment-start-regexp "+[ \t]*\\)+")
         (line-end-position) t))
    (back-to-indentation)))


;;; Filling

;; The default value should try not to break formulae across lines (this is
;; useful for preview-latex) and give a meaningful filling.
(defcustom LaTeX-fill-break-at-separators '(\\\( \\\[)
  "List of separators before or after which respectively a line
break will be inserted if they do not fit into one line."
  :group 'LaTeX
  :type '(set :tag "Contents"
              (const :tag "Opening Brace" \{)
              (const :tag "Closing Brace" \})
              (const :tag "Opening Bracket" \[)
              (const :tag "Opening Inline Math Switches" \\\()
              (const :tag "Closing Inline Math Switches" \\\))
              (const :tag "Opening Display Math Switch" \\\[)
              (const :tag "Closing Display Math Switch" \\\])))

(defcustom LaTeX-fill-break-before-code-comments t
  "If non-nil, a line with some code followed by a comment will
be broken before the last non-comment word in case the comment
does not fit into the line."
  :group 'LaTeX
  :type 'boolean)

(defcustom LaTeX-fill-excluded-macros nil
  "List of macro names (without leading \\) whose arguments must
not be subject to filling."
  :group 'LaTeX
  :type '(repeat string))

(defvar LaTeX-nospace-between-char-regexp "\\c|"
  "Regexp matching a character where no interword space is necessary.
Words formed by such characters can be broken across newlines.")

(defvar LaTeX-fill-newline-hook nil
  "Hook run after `LaTeX-fill-newline' inserted and indented a new line.")

(defun LaTeX-fill-region-as-paragraph (from to &optional justify-flag)
  "Fill region as one paragraph.
Break lines to fit `fill-column', but leave all lines ending with
\\\\ \(plus its optional argument) alone.  Lines with code
comments and lines ending with `\\par' are included in filling but
act as boundaries.  Prefix arg means justify too.  From program,
pass args FROM, TO and JUSTIFY-FLAG.

You can disable filling inside a specific environment by adding
it to `LaTeX-indent-environment-list', only indentation is
performed in that case."
  (interactive "*r\nP")
  (let ((end-marker (copy-marker to)) has-code-comment has-regexp-match)
    (if (or (assoc (LaTeX-current-environment) LaTeX-indent-environment-list)
            (member (TeX-current-macro) LaTeX-fill-excluded-macros)
            ;; This could be generalized, if there are more cases where
            ;; a special string at the start of a region to fill should
            ;; inhibit filling.
            (progn (save-excursion (goto-char from)
                                   (looking-at (concat TeX-comment-start-regexp
                                                       "+[ \t]*"
                                                       "Local Variables:")))))
        ;; Filling disabled, only do indentation.
        (indent-region from to nil)
      ;; XXX: This `save-restriction' is a leftover of older codes and
      ;; can now be removed.
      (save-restriction
        (goto-char from)
        (while (< (point) end-marker)
          ;; Code comments.
          (catch 'found
            (while (setq has-code-comment
                         (TeX-search-forward-comment-start end-marker))
              ;; See if there is at least one non-whitespace
              ;; character before the comment starts.
              (goto-char has-code-comment)
              (skip-chars-backward " \t" (line-beginning-position))
              (if (not (bolp))
                  ;; A real code comment.
                  (throw 'found t)
                ;; Not a code comment.  Continue the loop.
                (forward-line 1)
                (if (> (point) end-marker)
                    (goto-char end-marker)))))

          ;; Go back to the former point for the next regexp search.
          (goto-char from)

          (when (setq has-regexp-match
                      (re-search-forward
                       (concat
                        "\\("
                        ;; Lines ending with `\par'.
                        ;; XXX: Why exclude \n?  vv
                        "\\(?:\\=\\|[^" TeX-esc "\n]\\)\\(?:"
                        (regexp-quote (concat TeX-esc TeX-esc))
                        "\\)*"
                        (regexp-quote TeX-esc) "par[ \t]*"
                        ;; XXX: What's this "whitespaces in braces" ?
                        ;;    vvvvvvvv
                        "\\(?:{[ \t]*}\\)?[ \t]*$"
                        "\\)\\|"
                        ;; Lines ending with `\\'.
                        ;; XXX: This matches a line ending with "\\\ ".
                        ;; Should we avoid such corner case?
                        (regexp-quote (concat TeX-esc TeX-esc))
                        ;; XXX: Why not just "\\s-*\\*?" ?
                        "\\(?:\\s-*\\*\\)?"
                        ;; XXX: Why not "\\s-*\\(?:\\[[^]]*\\]\\)?" ?
                        "\\(?:\\s-*\\[[^]]*\\]\\)?"
                        "\\s-*$")
                       (or has-code-comment end-marker) t))
            ;; The regexp matched before the code comment (if any).
            (setq has-code-comment nil))

          ;; Here no need to go back to the former position because
          ;; "ELSE" part of the following `if' doesn't rely on the
          ;; current point.
          ;; (goto-char from)

          (if (or has-code-comment has-regexp-match)
              (progn
                (goto-char (or has-code-comment has-regexp-match))
                (goto-char (line-end-position))
                (delete-horizontal-space)
                ;; I doubt very much if we want justify -
                ;; this is a line with \\
                ;; if you think otherwise - uncomment the next line
                ;; (and justify-flag (justify-current-line))
                (forward-char)
                ;; keep our position in a buffer
                (save-excursion
                  ;; Code comments and lines ending with `\par' are
                  ;; included in filling.  Lines ending with `\\' are
                  ;; skipped.
                  (if (or has-code-comment
                          (match-beginning 1))
                      (LaTeX-fill-region-as-para-do from (point) justify-flag)
                    (LaTeX-fill-region-as-para-do
                     from (line-beginning-position 0) justify-flag)
                    ;; At least indent the line ending with `\\'.
                    (indent-according-to-mode)))
                (setq from (point)))
            ;; ELSE part follows - loop termination relies on a fact
            ;; that (LaTeX-fill-region-as-para-do) moves point past
            ;; the filled region
            (LaTeX-fill-region-as-para-do from end-marker justify-flag)))))
    (set-marker end-marker nil)))

;; The content of `LaTeX-fill-region-as-para-do' was copied from the
;; function `fill-region-as-paragraph' in `fill.el' (CVS Emacs,
;; January 2004) and adapted to the needs of AUCTeX.

(defun LaTeX-fill-region-as-para-do (from to &optional justify
                                          nosqueeze squeeze-after)
  "Fill the region defined by FROM and TO as one paragraph.
It removes any paragraph breaks in the region and extra newlines at the end,
indents and fills lines between the margins given by the
`current-left-margin' and `current-fill-column' functions.
\(In most cases, the variable `fill-column' controls the width.)
It leaves point at the beginning of the line following the paragraph.

Normally performs justification according to the `current-justification'
function, but with a prefix arg, does full justification instead.

From a program, optional third arg JUSTIFY can specify any type of
justification.  Fourth arg NOSQUEEZE non-nil means not to make spaces
between words canonical before filling.  Fifth arg SQUEEZE-AFTER, if non-nil,
means don't canonicalize spaces before that position.

Return the `fill-prefix' used for filling.

If `sentence-end-double-space' is non-nil, then period followed by one
space does not end a sentence, so don't break a line there."
  (interactive (progn
                 (barf-if-buffer-read-only)
                 (list (region-beginning) (region-end)
                       (if current-prefix-arg 'full))))
  (unless (memq justify '(t nil none full center left right))
    (setq justify 'full))

  ;; Make sure "to" is the endpoint.
  (goto-char (min from to))
  (setq to   (max from to))
  ;; Ignore blank lines at beginning of region.
  (skip-chars-forward " \t\n")

  (let ((from-plus-indent (point))
        (oneleft nil))

    (beginning-of-line)
    (setq from (point))

    ;; Delete all but one soft newline at end of region.
    ;; And leave TO before that one.
    (goto-char to)
    (while (and (> (point) from) (eq ?\n (char-after (1- (point)))))
      (if (and oneleft
               (not (and use-hard-newlines
                         (get-text-property (1- (point)) 'hard))))
          (delete-char -1)
        (backward-char 1)
        (setq oneleft t)))
    (setq to (copy-marker (point) t))
    (goto-char from-plus-indent))

  (if (not (> to (point)))
      ;; There is no paragraph, only whitespace: exit now.
      (progn
        (set-marker to nil)
        nil)

    (or justify (setq justify (current-justification)))

    ;; Don't let Adaptive Fill mode alter the fill prefix permanently.
    (let ((fill-prefix fill-prefix))
      ;; Figure out how this paragraph is indented, if desired.
      (when (and adaptive-fill-mode
                 (or (null fill-prefix) (string= fill-prefix "")))
        (setq fill-prefix (fill-context-prefix from to))
        ;; Ignore a white-space only fill-prefix
        ;; if we indent-according-to-mode.
        (when (and fill-prefix fill-indent-according-to-mode
                   (string-match "\\`[ \t]*\\'" fill-prefix))
          (setq fill-prefix nil)))

      (goto-char from)
      (beginning-of-line)

      (if (not justify)   ; filling disabled: just check indentation
          (progn
            (goto-char from)
            (while (< (point) to)
              (if (and (not (eolp))
                       (< (LaTeX-current-indentation) (current-left-margin)))
                  (fill-indent-to-left-margin))
              (forward-line 1)))

        (when use-hard-newlines
          (remove-text-properties from to '(hard nil)))
        ;; Make sure first line is indented (at least) to left margin...
        (indent-according-to-mode)
        ;; Delete the fill-prefix from every line.
        (fill-delete-prefix from to fill-prefix)

        (setq from (point))

        ;; FROM, and point, are now before the text to fill,
        ;; but after any fill prefix on the first line.

        (fill-delete-newlines from to justify nosqueeze squeeze-after)

        ;; This is the actual FILLING LOOP.
        (goto-char from)
        (let* (linebeg
               (code-comment-start (save-excursion
                                     (LaTeX-back-to-indentation)
                                     (TeX-search-forward-comment-start
                                      (line-end-position))))
               (end-marker (save-excursion
                             (goto-char (or code-comment-start to))
                             (point-marker)))
               (LaTeX-current-environment (LaTeX-current-environment)))
          ;; Fill until point is greater than the end point.  If there
          ;; is a code comment, use the code comment's start as a
          ;; limit.
          (while (and (< (point) (marker-position end-marker))
                      (or (not code-comment-start)
                          (and code-comment-start
                               (> (- (marker-position end-marker)
                                     (line-beginning-position))
                                  fill-column))))
            (setq linebeg (point))
            (move-to-column (current-fill-column))
            (if (when (< (point) (marker-position end-marker))
                  ;; Find the position where we'll break the line.
                  (forward-char 1)      ; Use an immediately following
                                        ; space, if any.
                  (LaTeX-fill-move-to-break-point linebeg)

                  ;; Check again to see if we got to the end of
                  ;; the paragraph.
                  (skip-chars-forward " \t")
                  (< (point) (marker-position end-marker)))
                ;; Found a place to cut.
                (progn
                  (LaTeX-fill-newline)
                  (when justify
                    ;; Justify the line just ended, if desired.
                    (save-excursion
                      (forward-line -1)
                      (justify-current-line justify nil t))))

              (goto-char end-marker)
              ;; Justify this last line, if desired.
              (if justify (justify-current-line justify t t))))

          ;; Fill a code comment if necessary.  (Enable this code if
          ;; you want the comment part in lines with code comments to
          ;; be filled.  Originally it was disabled because the
          ;; indentation code indented the lines following the line
          ;; with the code comment to the column of the comment
          ;; starters.  That means, it would have looked like this:
          ;; | code code code % comment
          ;; |                % comment
          ;; |                code code code
          ;; This now (2005-07-29) is not the case anymore.  But as
          ;; filling code comments like this would split a single
          ;; paragraph into two separate ones, we still leave it
          ;; disabled.  I leave the code here in case it is useful for
          ;; somebody.
          ;; (when (and code-comment-start
          ;;            (> (- (line-end-position) (line-beginning-position))
          ;;                  fill-column))
          ;;   (LaTeX-fill-code-comment justify))

          ;; The following is an alternative strategy to minimize the
          ;; occurence of overfull lines with code comments.  A line
          ;; will be broken before the last non-comment word if the
          ;; code comment does not fit into the line.
          (when (and LaTeX-fill-break-before-code-comments
                     code-comment-start
                     (> (- (line-end-position) (line-beginning-position))
                        fill-column))
            (beginning-of-line)
            (goto-char end-marker)
            (while (not (looking-at TeX-comment-start-regexp)) (forward-char))
            (skip-chars-backward " \t")
            (skip-chars-backward "^ \t\n")
            (unless (or (bolp)
                        ;; Comment starters and whitespace.
                        (TeX-looking-at-backward
                         (concat "^\\([ \t]*" TeX-comment-start-regexp "+\\)*"
                                 "[ \t]*")
                         (line-beginning-position)))
              (LaTeX-fill-newline)))
          (set-marker end-marker nil)))
      ;; Leave point after final newline.
      (goto-char to)
      (unless (eobp) (forward-char 1))
      (set-marker to nil)
      ;; Return the fill-prefix we used
      fill-prefix)))

(defun LaTeX-fill-move-to-break-point (linebeg)
  "Move to the position where the line should be broken.
See `fill-move-to-break-point' for the meaning of LINEBEG."
  (fill-move-to-break-point linebeg)
  ;; Prevent line break between 2-byte char and 1-byte char.
  (when (and (or (and (not (looking-at LaTeX-nospace-between-char-regexp))
                      (TeX-looking-at-backward
                       LaTeX-nospace-between-char-regexp 1))
                 (and (not (TeX-looking-at-backward
                            LaTeX-nospace-between-char-regexp 1))
                      (looking-at LaTeX-nospace-between-char-regexp)))
             (re-search-backward
              (concat LaTeX-nospace-between-char-regexp
                      LaTeX-nospace-between-char-regexp
                      LaTeX-nospace-between-char-regexp
                      "\\|"
                      ".\\ca\\s +\\ca") linebeg t))
    (if (looking-at "..\\c>")
        (forward-char 1)
      (forward-char 2)))
  ;; Cater for Japanese Macro
  (when (and (boundp 'japanese-TeX-mode) japanese-TeX-mode
             (aref (char-category-set (char-after)) ?j)
             (TeX-looking-at-backward (concat (regexp-quote TeX-esc) TeX-token-char "*")
                                      (1- (- (point) linebeg)))
             (not (TeX-escaped-p (match-beginning 0))))
    (goto-char (match-beginning 0)))
  (when LaTeX-fill-break-at-separators
    (let ((orig-breakpoint (point))
          (final-breakpoint (point))
          start-point)
      (save-excursion
        (beginning-of-line)
        (LaTeX-back-to-indentation 'outer)
        (setq start-point (point))
        ;; Find occurences of [, $, {, }, \(, \), \[, \] or $$.
        (while (and (= final-breakpoint orig-breakpoint)
                    (TeX-re-search-forward-unescaped
                     (concat "[[{}]\\|\\$\\$?\\|"
                             (regexp-quote TeX-esc) "[][()]")
                     orig-breakpoint t))
          (let ((match-string (match-string 0)))
            (cond
             ;; [ (opening bracket) (The closing bracket should
             ;; already be handled implicitely by the code for the
             ;; opening brace.)
             ((save-excursion
                (and (memq '\[ LaTeX-fill-break-at-separators)
                     (string= match-string "[")
                     (TeX-re-search-forward-unescaped (concat "\\][ \t]*{")
                                                      (line-end-position) t)
                     (> (- (or (TeX-find-closing-brace)
                               (line-end-position))
                           (line-beginning-position))
                        fill-column)))
              (save-excursion
                (skip-chars-backward "^ \n")
                (when (> (point) start-point)
                  (setq final-breakpoint (point)))))
             ;; { (opening brace)
             ((save-excursion
                (and (memq '\{ LaTeX-fill-break-at-separators)
                     (string= match-string "{")
                     (> (- (save-excursion
                             ;; `TeX-find-closing-brace' is not enough
                             ;; if there is no breakpoint in form of
                             ;; whitespace after the brace.
                             (goto-char (or (TeX-find-closing-brace)
                                            (line-end-position)))
                             (skip-chars-forward "^ \t\n")
                             (point))
                           (line-beginning-position))
                        fill-column)))
              (save-excursion
                (skip-chars-backward "^ \n")
                ;; The following is a primitive and error-prone method
                ;; to cope with point probably being inside square
                ;; brackets.  A better way would be to use functions
                ;; to determine if point is inside an optional
                ;; argument and to jump to the start and end brackets.
                (when (save-excursion
                        (TeX-re-search-forward-unescaped
                         (concat "\\][ \t]*{") orig-breakpoint t))
                  (TeX-search-backward-unescaped "["
                                                 (line-beginning-position) t)
                  (skip-chars-backward "^ \n"))
                (when (> (point) start-point)
                  (setq final-breakpoint (point)))))
             ;; } (closing brace)
             ((save-excursion
                (and (memq '\} LaTeX-fill-break-at-separators)
                     (string= match-string "}")
                     (save-excursion
                       (backward-char 2)
                       (not (TeX-find-opening-brace
                             nil (line-beginning-position))))))
              (save-excursion
                (skip-chars-forward "^ \n")
                (when (> (point) start-point)
                  (setq final-breakpoint (point)))))
             ;; $ or \( or \[ or $$ (opening math)
             ((save-excursion
                (and (or (and (memq '\\\( LaTeX-fill-break-at-separators)
                              (or (and (string= match-string "$")
                                       (texmathp))
                                  (string= match-string "\\(")))
                         (and (memq '\\\[ LaTeX-fill-break-at-separators)
                              (or (string= match-string "\\[")
                                  (and (string= match-string "$$")
                                       (texmathp)))))
                     (> (- (save-excursion
                             (TeX-search-forward-unescaped
                              (cond ((string= match-string "\\(")
                                     (concat TeX-esc ")"))
                                    ((string= match-string "$") "$")
                                    ((string= match-string "$$") "$$")
                                    (t (concat TeX-esc "]")))
                              (point-max) t)
                             (skip-chars-forward "^ \n")
                             (point))
                           (line-beginning-position))
                        fill-column)))
              (save-excursion
                (skip-chars-backward "^ \n")
                (when (> (point) start-point)
                  (setq final-breakpoint (point)))))
             ;; $ or \) or \] or $$ (closing math)
             ((save-excursion
                (and (or (and (memq '\\\) LaTeX-fill-break-at-separators)
                              (or (and (string= match-string "$")
                                       (not (texmathp)))
                                  (string= match-string "\\)")))
                         (and (memq '\\\] LaTeX-fill-break-at-separators)
                              (or (string= match-string "\\]")
                                  (and (string= match-string "$$")
                                       (not (texmathp))))))
                     (if (member match-string '("$" "$$"))
                         (save-excursion
                           (skip-chars-backward "$")
                           (TeX-search-backward-unescaped
                            match-string (line-beginning-position) t))
                       (texmathp-match-switch (line-beginning-position)))))
              (save-excursion
                (skip-chars-forward "^ \n")
                (when (> (point) start-point)
                  (setq final-breakpoint (point)))))))))
      (goto-char final-breakpoint))))

;; The content of `LaTeX-fill-newline' was copied from the function
;; `fill-newline' in `fill.el' (CVS Emacs, January 2004) and adapted
;; to the needs of AUCTeX.
(defun LaTeX-fill-newline ()
  "Replace whitespace here with one newline and indent the line."
  (skip-chars-backward " \t")
  (insert ?\n)
  ;; Give newline the properties of the space(s) it replaces
  (set-text-properties (1- (point)) (point)
                       (text-properties-at (point)))
  (and (looking-at "\\( [ \t]*\\)\\(\\c|\\)?")
       (or (aref (char-category-set (or (char-before (1- (point))) ?\000)) ?|)
           (match-end 2))
       ;; When refilling later on, this newline would normally not
       ;; be replaced by a space, so we need to mark it specially to
       ;; re-install the space when we unfill.
       (put-text-property (1- (point)) (point) 'fill-space (match-string 1)))
  ;; If we don't want breaks in invisible text, don't insert
  ;; an invisible newline.
  (if fill-nobreak-invisible
      (remove-text-properties (1- (point)) (point)
                              '(invisible t)))
  ;; Insert the fill prefix.
  (and fill-prefix (not (equal fill-prefix ""))
       ;; Markers that were after the whitespace are now at point: insert
       ;; before them so they don't get stuck before the prefix.
       (insert-before-markers-and-inherit fill-prefix))
  (indent-according-to-mode)
  (run-hooks 'LaTeX-fill-newline-hook))

(defun LaTeX-fill-paragraph (&optional justify)
  "Like `fill-paragraph', but handle LaTeX comments.

With prefix argument JUSTIFY, justify as well.

If any of the current line is a comment, fill the comment or the
paragraph of it that point is in.  Code comments, that is, comments
with uncommented code preceding them in the same line, will not
be filled unless the cursor is placed on the line with the
code comment.

If LaTeX syntax is taken into consideration during filling
depends on the value of `LaTeX-syntactic-comments'."
  (interactive "*P")
  (if (save-excursion
        (beginning-of-line)
        (looking-at (concat TeX-comment-start-regexp "*[ \t]*$")))
      ;; Don't do anything if we look at an empty line and let
      ;; `fill-paragraph' think we successfully filled the paragraph.
      t
    (let (;; Non-nil if the current line contains a comment.
          has-comment
          ;; Non-nil if the current line contains code and a comment.
          has-code-and-comment
          code-comment-start
          ;; If has-comment, the appropriate fill-prefix for the comment.
          comment-fill-prefix)

      ;; Figure out what kind of comment we are looking at.
      (cond
       ;; A line only with potential whitespace followed by a
       ;; comment on it?
       ((save-excursion
          (beginning-of-line)
          (looking-at (concat "^[ \t]*" TeX-comment-start-regexp
                              "\\(" TeX-comment-start-regexp "\\|[ \t]\\)*")))
        (setq has-comment t
              comment-fill-prefix (TeX-match-buffer 0)))
       ;; A line with some code, followed by a comment?
       ((and (setq code-comment-start (save-excursion
                                        (beginning-of-line)
                                        (TeX-search-forward-comment-start
                                         (line-end-position))))
             (> (point) code-comment-start)
             (not (TeX-in-commented-line))
             (save-excursion
               (goto-char code-comment-start)
               ;; See if there is at least one non-whitespace character
               ;; before the comment starts.
               (re-search-backward "[^ \t\n]" (line-beginning-position) t)))
        (setq has-comment t
              has-code-and-comment t)))

      (cond
       ;; Code comments.
       (has-code-and-comment
        (save-excursion
          (when (>= (- code-comment-start (line-beginning-position))
                    fill-column)
            ;; If start of code comment is beyond fill column, fill it as a
            ;; regular paragraph before it is filled as a code comment.
            (let ((end-marker (save-excursion (end-of-line) (point-marker))))
              (LaTeX-fill-region-as-paragraph (line-beginning-position)
                                              (line-beginning-position 2)
                                              justify)
              (goto-char end-marker)
              (beginning-of-line)
              (set-marker end-marker nil)))
          (LaTeX-fill-code-comment justify)))
       ;; Syntax-aware filling:
       ;; * `LaTeX-syntactic-comments' enabled: Everything.
       ;; * `LaTeX-syntactic-comments' disabled: Uncommented code and
       ;;   line comments in `docTeX-mode'.
       ((or (or LaTeX-syntactic-comments
                (and (not LaTeX-syntactic-comments)
                     (not has-comment)))
            (and (eq major-mode 'docTeX-mode)
                 (TeX-in-line-comment)))
        (let ((fill-prefix comment-fill-prefix))
          (save-excursion
            (let* ((end (progn (LaTeX-forward-paragraph)
                               (or (bolp) (newline 1))
                               (and (eobp) (not (bolp)) (open-line 1))
                               (point)))
                   (start
                    (progn
                      (LaTeX-backward-paragraph)
                      (while (and (looking-at
                                   (concat "$\\|[ \t]+$\\|"
                                           "[ \t]*" TeX-comment-start-regexp
                                           "+[ \t]*$"))
                                  (< (point) end))
                        (forward-line))
                      (point))))
              (LaTeX-fill-region-as-paragraph start end justify)))))
        ;; Non-syntax-aware filling.
       (t
        (save-excursion
          (save-restriction
            (beginning-of-line)
            (narrow-to-region
             ;; Find the first line we should include in the region to fill.
             (save-excursion
               (while (and (zerop (forward-line -1))
                           (looking-at (concat "^[ \t]*"
                                               TeX-comment-start-regexp))))
               ;; We may have gone too far.  Go forward again.
               (or (looking-at (concat ".*" TeX-comment-start-regexp))
                   (forward-line 1))
               (point))
             ;; Find the beginning of the first line past the region to fill.
             (save-excursion
               (while (progn (forward-line 1)
                             (looking-at (concat "^[ \t]*"
                                                 TeX-comment-start-regexp))))
               (point)))
            ;; The definitions of `paragraph-start' and
            ;; `paragraph-separate' will still make
            ;; `forward-paragraph' and `backward-paragraph' stop at
            ;; the respective (La)TeX commands.  If these should be
            ;; disregarded, the definitions would have to be changed
            ;; accordingly.  (Lines with only `%' characters on them
            ;; can be paragraph boundaries.)
            (let* ((paragraph-start
                    (concat paragraph-start "\\|"
                            "\\(" TeX-comment-start-regexp "\\|[ \t]\\)*$"))
                   (paragraph-separate
                    (concat paragraph-separate "\\|"
                            "\\(" TeX-comment-start-regexp "\\|[ \t]\\)*$"))
                   (fill-prefix comment-fill-prefix)
                   (end (progn (forward-paragraph)
                               (or (bolp) (newline 1))
                               (point)))
                   (beg (progn (backward-paragraph)
                               (point))))
              (fill-region-as-paragraph
               beg end
               justify nil
               (save-excursion
                 (goto-char beg)
                 (if (looking-at fill-prefix)
                     nil
                   (re-search-forward comment-start-skip nil t)
                   (point)))))))))
      t)))

(defun LaTeX-fill-code-comment (&optional justify-flag)
  "Fill a line including code followed by a comment."
  (let ((beg (line-beginning-position))
        fill-prefix code-comment-start)
    (indent-according-to-mode)
    (when (when (setq code-comment-start (save-excursion
                                           (goto-char beg)
                                           (TeX-search-forward-comment-start
                                            (line-end-position))))
            (goto-char code-comment-start)
            (while (not (looking-at TeX-comment-start-regexp)) (forward-char))
            ;; See if there is at least one non-whitespace character
            ;; before the comment starts.
            (save-excursion
              (re-search-backward "[^ \t\n]" (line-beginning-position) t)))
      (setq fill-prefix
            (concat
             (if indent-tabs-mode
                 (concat (make-string (/ (current-column) tab-width) ?\t)
                         (make-string (% (current-column) tab-width) ?\ ))
               (make-string (current-column) ?\ ))
             (progn
               (looking-at (concat TeX-comment-start-regexp "+[ \t]*"))
               (TeX-match-buffer 0))))
      (fill-region-as-paragraph beg (line-beginning-position 2)
                                justify-flag  nil
                                (save-excursion
                                  (goto-char beg)
                                  (if (looking-at fill-prefix)
                                      nil
                                    (re-search-forward comment-start-skip nil t)
                                    (point)))))))

(defun LaTeX-fill-region (from to &optional justify what)
  "Fill and indent the text in region from FROM to TO as LaTeX text.
Prefix arg (non-nil third arg JUSTIFY, if called from program)
means justify as well.  Fourth arg WHAT is a word to be displayed when
formatting."
  (interactive "*r\nP")
  (save-excursion
    (let ((to (set-marker (make-marker) to))
          (next-par (make-marker)))
      (goto-char from)
      (beginning-of-line)
      (setq from (point))
      (catch 'end-of-buffer
        (while (and (< (point) to))
          (message "Formatting%s...%d%%"
                   (or what "")
                   (/ (* 100 (- (point) from)) (- to from)))
          (save-excursion (LaTeX-fill-paragraph justify))
          (if (marker-position next-par)
              (goto-char (marker-position next-par))
            (LaTeX-forward-paragraph))
          (when (eobp) (throw 'end-of-buffer t))
          (LaTeX-forward-paragraph)
          (set-marker next-par (point))
          (LaTeX-backward-paragraph)
          (while (and (not (eobp))
                      (looking-at
                       (concat "^\\($\\|[ \t]+$\\|[ \t]*"
                               TeX-comment-start-regexp "+[ \t]*$\\)")))
            (forward-line 1))))
      (set-marker next-par nil)
      (set-marker to nil)))
  (message "Formatting%s...done" (or what "")))

(defun LaTeX-find-matching-end ()
  "Move point to the \\end of the current environment.

If function is called inside a comment and
`LaTeX-syntactic-comments' is enabled, try to find the
environment in commented regions with the same comment prefix."
  (interactive)
  (let* ((regexp (concat (regexp-quote TeX-esc) "\\(begin\\|end\\)\\b"))
         (level 1)
         (in-comment (TeX-in-commented-line))
         (comment-prefix (and in-comment (TeX-comment-prefix)))
         (case-fold-search nil))
    ;; The following code until `while' handles exceptional cases that
    ;; the point is on "\begin{foo}" or "\end{foo}".
    ;; Note that it doesn't work for "\end{\foo{bar}}".  See bug#19281.
    (let ((pt (point)))
      (skip-chars-backward (concat "a-zA-Z* \t" TeX-grop))
      (unless (bolp)
        (backward-char 1)
        (if (and (looking-at regexp)
                 (char-equal (char-after (match-beginning 1)) ?e))
            (setq level 0)
          (goto-char pt))))
    (while (and (> level 0) (re-search-forward regexp nil t))
      (when (or (and LaTeX-syntactic-comments
                     (eq in-comment (TeX-in-commented-line))
                     ;; If we are in a commented line, check if the
                     ;; prefix matches the one we started out with.
                     (or (not in-comment)
                         (string= comment-prefix (TeX-comment-prefix))))
                (and (not LaTeX-syntactic-comments)
                     (not (TeX-in-commented-line)))
                ;; macrocode*? in docTeX-mode is special since we have
                ;; also regular code lines not starting with a
                ;; comment-prefix.  Hence, the next check just looks
                ;; if we're inside such a group and returns non-nil to
                ;; recognize such a situation.
                (and (eq major-mode 'docTeX-mode)
                     (looking-at-p " *{macrocode\\*?}")))
        (setq level
              (if (= (char-after (match-beginning 1)) ?b) ;;begin
                  (1+ level)
                (1- level)))))
    (if (= level 0)
        (re-search-forward
         (concat TeX-grop (LaTeX-environment-name-regexp) TeX-grcl))
      (error "Can't locate end of current environment"))))

(defun LaTeX-find-matching-begin ()
  "Move point to the \\begin of the current environment.

If function is called inside a comment and
`LaTeX-syntactic-comments' is enabled, try to find the
environment in commented regions with the same comment prefix."
  (interactive)
  (let (done)
    ;; The following code until `or' handles exceptional cases that
    ;; the point is on "\begin{foo}" or "\end{foo}".
    ;; Note that it doesn't work for "\end{\foo{bar}}". See bug#19281.
    (skip-chars-backward (concat "a-zA-Z* \t" TeX-grop))
    (unless (bolp)
      (backward-char 1)
      (and (looking-at (concat (regexp-quote TeX-esc) "begin\\b"))
           (setq done t)))
    (or done
        (LaTeX-backward-up-environment)
        (error "Can't locate beginning of current environment"))))

(defun LaTeX-mark-environment (&optional count)
  "Set mark to end of current environment and point to the matching begin.
If prefix argument COUNT is given, mark the respective number of
enclosing environments.  The command will not work properly if
there are unbalanced begin-end pairs in comments and verbatim
environments."
  (interactive "p")
  (setq count (if count (abs count) 1))
  (let ((cur (point)) beg end)
    ;; Only change point and mark after beginning and end were found.
    ;; Point should not end up in the middle of nowhere if the search fails.
    (save-excursion
      (dotimes (_ count) (LaTeX-find-matching-end))
      (setq end (line-beginning-position 2))
      (goto-char cur)
      (dotimes (_ count) (LaTeX-find-matching-begin))
      (setq beg (point)))
    (push-mark end)
    (goto-char beg)
    (TeX-activate-region)))

(defun LaTeX-fill-environment (justify)
  "Fill and indent current environment as LaTeX text.

With prefix argument JUSTIFY, justify as well."
  (interactive "*P")
  (save-excursion
    (LaTeX-mark-environment)
    (re-search-forward "{\\([^}]+\\)}")
    (LaTeX-fill-region (region-beginning) (region-end) justify
                       (concat " environment " (TeX-match-buffer 1)))))

(defun LaTeX-fill-section (justify)
  "Fill and indent current logical section as LaTeX text.

With prefix argument JUSTIFY, justify as well."
  (interactive "*P")
  (save-excursion
    (LaTeX-mark-section)
    (re-search-forward "{\\([^}]+\\)}")
    (LaTeX-fill-region (region-beginning) (region-end) justify
                       (concat " section " (TeX-match-buffer 1)))))

(defun LaTeX-mark-section (&optional no-subsections)
  "Set mark at end of current logical section, and point at top.
If optional argument NO-SUBSECTIONS is non-nil, mark only the
region from the current section start to the next sectioning
command.  Thereby subsections are not being marked.

If the function `outline-mark-subtree' is not available,
`LaTeX-mark-section' always behaves like this regardless of the
value of NO-SUBSECTIONS."
  (interactive "P")
  (if (or no-subsections
          (not (fboundp 'outline-mark-subtree)))
      (progn
        (re-search-forward (concat  "\\(" (LaTeX-outline-regexp)
                                    "\\|\\'\\)"))
        (beginning-of-line)
        (push-mark (point) nil t)
        (re-search-backward (concat "\\(" (LaTeX-outline-regexp)
                                    "\\|\\`\\)")))
    (outline-mark-subtree)
    (when (and transient-mark-mode
               (not mark-active))
      (setq mark-active t)
      (run-hooks 'activate-mark-hook)))
  (TeX-activate-region))

(defun LaTeX-fill-buffer (justify)
  "Fill and indent current buffer as LaTeX text.

With prefix argument JUSTIFY, justify as well."
  (interactive "*P")
  (save-excursion
    (LaTeX-fill-region
     (point-min)
     (point-max)
     justify
     (concat " buffer " (buffer-name)))))


;;; Navigation

(defvar LaTeX-paragraph-commands-internal
  '("[" "]" ; display math
    "appendix" "begin" "caption" "chapter" "end" "include" "includeonly"
    "label" "maketitle" "newblock" "noindent" "par" "paragraph" "part"
    "section" "subsection" "subsubsection" "tableofcontents"
    "newpage" "clearpage")
  "Internal list of LaTeX macros that should have their own line.")

(defvar LaTeX-paragraph-commands)

(defun LaTeX-paragraph-commands-regexp-make ()
  "Return a regular expression matching defined paragraph commands.
Regexp part containing TeX control words is postfixed with `\\b'
to avoid ambiguities (for example, \\par vs. \\parencite)."
  (let (cmds symbs)
    (dolist (mac (append LaTeX-paragraph-commands
                         LaTeX-paragraph-commands-internal))
      (if (string-match "[^a-zA-Z]" mac)
          (push mac symbs)
        (push mac cmds)))
    (concat (regexp-quote TeX-esc) "\\(?:"
            (regexp-opt cmds "\\(?:")
            "\\b"
            "\\|"
            (regexp-opt symbs)
            "\\)")))

(defvar LaTeX-paragraph-commands-regexp)

(defcustom LaTeX-paragraph-commands nil
  "List of LaTeX macros that should have their own line.
The list should contain macro names without the leading backslash."
  :group 'LaTeX-macro
  :type '(repeat (string))
  :set (lambda (symbol value)
         (set-default symbol value)
         (setq LaTeX-paragraph-commands-regexp
               (LaTeX-paragraph-commands-regexp-make))))

(defvar LaTeX-paragraph-commands-regexp (LaTeX-paragraph-commands-regexp-make)
  "Regular expression matching LaTeX macros that should have their own line.")

(defun LaTeX-set-paragraph-start ()
  "Set `paragraph-start'."
  (setq paragraph-start
        (concat
         "[ \t]*%*[ \t]*\\("
         LaTeX-paragraph-commands-regexp "\\|"
         (regexp-quote TeX-esc) "\\(" LaTeX-item-regexp "\\)\\|"
         "\\$\\$\\|"    ; Plain TeX display math (Some people actually use this
                                        ; with LaTeX.  Yuck.)
         "$\\)")))

(defun LaTeX-paragraph-commands-add-locally (commands)
  "Make COMMANDS be recognized as paragraph commands.
COMMANDS can be a single string or a list of strings which will
be added to `LaTeX-paragraph-commands-internal'.  Additionally
`LaTeX-paragraph-commands-regexp' will be updated and both
variables will be made buffer-local.  This is mainly a
convenience function which can be used in style files."
  (make-local-variable 'LaTeX-paragraph-commands-internal)
  (make-local-variable 'LaTeX-paragraph-commands-regexp)
  (unless (listp commands) (setq commands (list commands)))
  (dolist (elt commands)
    (add-to-list 'LaTeX-paragraph-commands-internal elt))
  (setq LaTeX-paragraph-commands-regexp (LaTeX-paragraph-commands-regexp-make))
  (LaTeX-set-paragraph-start))

(defun LaTeX-forward-paragraph (&optional count)
  "Move forward to end of paragraph.
If COUNT is non-nil, do it COUNT times."
  (or count (setq count 1))
  (dotimes (_ count)
    (let* ((macro-start (TeX-find-macro-start))
           (paragraph-command-start
            (cond
             ;; Point is inside of a paragraph command.
             ((and macro-start
                   (save-excursion
                     (goto-char macro-start)
                     (looking-at LaTeX-paragraph-commands-regexp)))
              (match-beginning 0))
             ;; Point is before a paragraph command in the same line.
             ((looking-at
               (concat "[ \t]*\\(?:" TeX-comment-start-regexp
                       "\\(?:" TeX-comment-start-regexp "\\|[ \t]\\)*\\)?"
                       "\\(" LaTeX-paragraph-commands-regexp "\\)"))
              (match-beginning 1))))
           macro-end)
      ;; If a paragraph command is encountered there are two cases to be
      ;; distinguished:
      ;; 1) If the end of the paragraph command coincides (apart from
      ;;    potential whitespace) with the end of the line, is only
      ;;    followed by a comment or is directly followed by a macro,
      ;;    it is assumed that it should be handled separately.
      ;; 2) If the end of the paragraph command is followed by other
      ;;    code, it is assumed that it should be included with the rest
      ;;    of the paragraph.
      (if (and paragraph-command-start
               (save-excursion
                 (goto-char paragraph-command-start)
                 (setq macro-end (goto-char (TeX-find-macro-end)))
                 (looking-at (concat (regexp-quote TeX-esc) "[@A-Za-z]+\\|"
                                     "[ \t]*\\($\\|"
                                     TeX-comment-start-regexp "\\)"))))
          (progn
            (goto-char macro-end)
            ;; If the paragraph command is followed directly by
            ;; another macro, regard the latter as part of the
            ;; paragraph command's paragraph.
            (when (looking-at (concat (regexp-quote TeX-esc) "[@A-Za-z]+"))
              (goto-char (TeX-find-macro-end)))
            (forward-line))
        (let (limit)
          (goto-char (min (save-excursion
                            (forward-paragraph)
                            (setq limit (point)))
                          (save-excursion
                            (TeX-forward-comment-skip 1 limit)
                            (point)))))))))

(defun LaTeX-backward-paragraph (&optional count)
  "Move backward to beginning of paragraph.
If COUNT is non-nil, do it COUNT times."
  (or count (setq count 1))
  (dotimes (_ count)
    (let* ((macro-start (TeX-find-macro-start)))
      (if (and macro-start
               ;; Point really has to be inside of the macro, not before it.
               (not (= macro-start (point)))
               (save-excursion
                 (goto-char macro-start)
                 (looking-at LaTeX-paragraph-commands-regexp)))
          ;; Point is inside of a paragraph command.
          (progn
            (goto-char macro-start)
            (beginning-of-line))
        (let (limit
              (start (line-beginning-position)))
          (goto-char
           (max (save-excursion
                  (backward-paragraph)
                  (setq limit (point)))
                ;; Search for possible transitions from commented to
                ;; uncommented regions and vice versa.
                (save-excursion
                  (TeX-backward-comment-skip 1 limit)
                  (point))
                ;; Search for paragraph commands.
                (save-excursion
                  (let ((end-point 0) macro-bol)
                    (when (setq macro-bol
                                (re-search-backward
                                 (format "^[ \t]*%s*[ \t]*\\(%s\\)"
                                         TeX-comment-start-regexp
                                         LaTeX-paragraph-commands-regexp)
                                 limit t))
                      (if (and (string= (match-string 1) "\\begin")
                               (progn
                                 (goto-char (match-end 1))
                                 (skip-chars-forward "{ \t")
                                 (member (buffer-substring-no-properties
                                          (point) (progn (skip-chars-forward
                                                          "A-Za-z*") (point)))
                                         LaTeX-verbatim-environments)))
                          ;; If inside a verbatim environment, just
                          ;; use the next line.  In such environments
                          ;; `TeX-find-macro-end' could otherwise
                          ;; think brackets or braces belong to the
                          ;; \begin macro.
                          (setq end-point (line-beginning-position 2))
                        ;; Jump to the macro end otherwise.
                        (goto-char (match-beginning 1))
                        (goto-char (TeX-find-macro-end))
                        ;; For an explanation of this distinction see
                        ;; `LaTeX-forward-paragraph'.
                        (if (looking-at (concat (regexp-quote TeX-esc)
                                                "[@A-Za-z]+\\|[ \t]*\\($\\|"
                                                TeX-comment-start-regexp "\\)"))
                            (progn
                              (when (looking-at (regexp-quote TeX-esc))
                                (goto-char (TeX-find-macro-end)))
                              (forward-line 1)
                              (when (< (point) start)
                                (setq end-point (point))))
                          (setq end-point macro-bol))))
                    end-point)))))))))

(defun LaTeX-search-forward-comment-start (&optional limit)
  "Search forward for a comment start from current position till LIMIT.
If LIMIT is omitted, search till the end of the buffer.

This function makes sure that any comment starters found inside
of verbatim constructs are not considered."
  (setq limit (or limit (point-max)))
  (save-excursion
    (let (start)
      (catch 'found
        (while (progn
                 (when (and (TeX-re-search-forward-unescaped
                             TeX-comment-start-regexp limit 'move)
                            (not (LaTeX-verbatim-p)))
                   (setq start (match-beginning 0))
                   (throw 'found t))
                 (< (point) limit))))
      start)))


;;; Math Minor Mode

(defvar LaTeX-math-mode-map)

(defgroup LaTeX-math nil
  "Mathematics in AUCTeX."
  :group 'LaTeX-macro)

(defvar LaTeX-math-keymap (make-sparse-keymap)
  "Keymap used for `LaTeX-math-mode' commands.")

(defcustom LaTeX-math-abbrev-prefix "`"
  "Prefix key for use in `LaTeX-math-mode'.
This has to be a string representing a key sequence in a format
understood by the `kbd' macro.  This corresponds to the syntax
usually used in the Emacs and Elisp manuals.

Setting this variable directly does not take effect;
use \\[customize]."
  :group 'LaTeX-math
  :initialize #'custom-initialize-default
  :set (lambda (symbol value)
         (define-key LaTeX-math-mode-map (LaTeX-math-abbrev-prefix) t)
         (set-default symbol value)
         (define-key LaTeX-math-mode-map
           (LaTeX-math-abbrev-prefix) LaTeX-math-keymap))
  :type '(string :tag "Key sequence"))

(defun LaTeX-math-abbrev-prefix ()
  "Make a key definition from the variable `LaTeX-math-abbrev-prefix'."
  (if (stringp LaTeX-math-abbrev-prefix)
      (read-kbd-macro LaTeX-math-abbrev-prefix)
    LaTeX-math-abbrev-prefix))

(defvar LaTeX-math-menu
  '("Math"
    ("Greek Uppercase") ("Greek Lowercase") ("Binary Op") ("Relational")
    ("Arrows") ("Punctuation") ("Misc Symbol") ("Var Symbol") ("Log-like")
    ("Delimiters") ("Constructs") ("Accents") ("AMS") ("Wasysym"))
  "Menu containing LaTeX math commands.
The menu entries will be generated dynamically, but you can specify
the sequence by initializing this variable.")

(defconst LaTeX-math-default
  '((?a "alpha" "Greek Lowercase" 945) ;; #X03B1
    (?b "beta" "Greek Lowercase" 946) ;; #X03B2
    (?g "gamma" "Greek Lowercase" 947) ;; #X03B3
    (?d "delta" "Greek Lowercase" 948) ;; #X03B4
    (?e "epsilon" "Greek Lowercase" 1013) ;; #X03F5
    (?z "zeta" "Greek Lowercase" 950) ;; #X03B6
    (?h "eta" "Greek Lowercase" 951) ;; #X03B7
    (?j "theta" "Greek Lowercase" 952) ;; #X03B8
    (nil "iota" "Greek Lowercase" 953) ;; #X03B9
    (?k "kappa" "Greek Lowercase" 954) ;; #X03BA
    (?l "lambda" "Greek Lowercase" 955) ;; #X03BB
    (?m "mu" "Greek Lowercase" 956) ;; #X03BC
    (?n "nu" "Greek Lowercase" 957) ;; #X03BD
    (?x "xi" "Greek Lowercase" 958) ;; #X03BE
    (?p "pi" "Greek Lowercase" 960) ;; #X03C0
    (?r "rho" "Greek Lowercase" 961) ;; #X03C1
    (?s "sigma" "Greek Lowercase" 963) ;; #X03C3
    (?t "tau" "Greek Lowercase" 964) ;; #X03C4
    (?u "upsilon" "Greek Lowercase" 965) ;; #X03C5
    (?f "phi" "Greek Lowercase" 981) ;; #X03D5
    (?q "chi" "Greek Lowercase" 967) ;; #X03C7
    (?y "psi" "Greek Lowercase" 968) ;; #X03C8
    (?w "omega" "Greek Lowercase" 969) ;; #X03C9
    ("v e" "varepsilon" "Greek Lowercase" 949) ;; #X03B5
    ("v j" "vartheta" "Greek Lowercase" 977) ;; #X03D1
    ("v p" "varpi" "Greek Lowercase" 982) ;; #X03D6
    ("v r" "varrho" "Greek Lowercase" 1009) ;; #X03F1
    ("v s" "varsigma" "Greek Lowercase" 962) ;; #X03C2
    ("v f" "varphi" "Greek Lowercase" 966) ;; #X03C6
    (?G "Gamma" "Greek Uppercase" 915) ;; #X0393
    (?D "Delta" "Greek Uppercase" 916) ;; #X0394
    (?J "Theta" "Greek Uppercase" 920) ;; #X0398
    (?L "Lambda" "Greek Uppercase" 923) ;; #X039B
    (?X "Xi" "Greek Uppercase" 926) ;; #X039E
    (?P "Pi" "Greek Uppercase" 928) ;; #X03A0
    (?S "Sigma" "Greek Uppercase" 931) ;; #X03A3
    (?U "Upsilon" "Greek Uppercase" 978) ;; #X03D2
    (?F "Phi" "Greek Uppercase" 934) ;; #X03A6
    (?Y "Psi" "Greek Uppercase" 936) ;; #X03A8
    (?W "Omega" "Greek Uppercase" 937) ;; #X03A9
    (?c LaTeX-math-cal "Cal-whatever")
    (nil "pm" "Binary Op" 177) ;; #X00B1
    (nil "mp" "Binary Op" 8723) ;; #X2213
    (?* "times" "Binary Op" 215) ;; #X00D7
    (nil "div" "Binary Op" 247) ;; #X00F7
    (nil "ast" "Binary Op" 8727) ;; #X2217
    (nil "star" "Binary Op" 8902) ;; #X22C6
    (nil "circ" "Binary Op" 8728) ;; #X2218
    (nil "bullet" "Binary Op" 8729) ;; #X2219
    (?. "cdot" "Binary Op" 8901) ;; #X22C5
    (?- "cap" "Binary Op" 8745) ;; #X2229
    (?+ "cup" "Binary Op" 8746) ;; #X222A
    (nil "uplus" "Binary Op" 8846) ;; #X228E
    (nil "sqcap" "Binary Op" 8851) ;; #X2293
    (?| "vee" "Binary Op" 8744) ;; #X2228
    (?& "wedge" "Binary Op" 8743) ;; #X2227
    (?\\ "setminus" "Binary Op" 8726) ;; #X2216
    (nil "wr" "Binary Op" 8768) ;; #X2240
    (nil "diamond" "Binary Op" 8900) ;; #X22C4
    (nil "bigtriangleup" "Binary Op" 9651) ;; #X25B3
    (nil "bigtriangledown" "Binary Op" 9661) ;; #X25BD
    (nil "triangleleft" "Binary Op" 9665) ;; #X25C1
    (nil "triangleright" "Binary Op" 9655) ;; #X25B7
    (nil "lhd" "Binary Op" 8882) ;; #X22B2
    (nil "rhd" "Binary Op" 8883) ;; #X22B3
    (nil "unlhd" "Binary Op" 8884) ;; #X22B4
    (nil "unrhd" "Binary Op" 8885) ;; #X22B5
    (nil "oplus" "Binary Op" 8853) ;; #X2295
    (nil "ominus" "Binary Op" 8854) ;; #X2296
    (nil "otimes" "Binary Op" 8855) ;; #X2297
    (nil "oslash" "Binary Op" 8709) ;; #X2205
    (nil "odot" "Binary Op" 8857) ;; #X2299
    (nil "bigcirc" "Binary Op" 9675) ;; #X25CB
    (nil "dagger" "Binary Op" 8224) ;; #X2020
    (nil "ddagger" "Binary Op" 8225) ;; #X2021
    (nil "amalg" "Binary Op" 10815) ;; #X2A3F
    (?< "leq" "Relational" 8804) ;; #X2264
    (?> "geq" "Relational" 8805) ;; #X2265
    (nil "qed" "Relational" 8718) ;; #X220E
    (nil "equiv" "Relational" 8801) ;; #X2261
    (nil "models" "Relational" 8871) ;; #X22A7
    (nil "prec" "Relational" 8826) ;; #X227A
    (nil "succ" "Relational" 8827) ;; #X227B
    (nil "sim" "Relational" 8764) ;; #X223C
    (nil "perp" "Relational" 10178) ;; #X27C2
    (nil "preceq" "Relational" 10927) ;; #X2AAF
    (nil "succeq" "Relational" 10928) ;; #X2AB0
    (nil "simeq" "Relational" 8771) ;; #X2243
    (nil "mid" "Relational" 8739) ;; #X2223
    (nil "ll" "Relational" 8810) ;; #X226A
    (nil "gg" "Relational" 8811) ;; #X226B
    (nil "asymp" "Relational" 8781) ;; #X224D
    (nil "parallel" "Relational" 8741) ;; #X2225
    (?\{ "subset" "Relational" 8834) ;; #X2282
    (?\} "supset" "Relational" 8835) ;; #X2283
    (nil "approx" "Relational" 8776) ;; #X2248
    (nil "bowtie" "Relational" 8904) ;; #X22C8
    (?\[ "subseteq" "Relational" 8838) ;; #X2286
    (?\] "supseteq" "Relational" 8839) ;; #X2287
    (nil "cong" "Relational" 8773) ;; #X2245
    (nil "Join" "Relational" 10781) ;; #X2A1D
    (nil "sqsubset" "Relational" 8847) ;; #X228F
    (nil "sqsupset" "Relational" 8848) ;; #X2290
    (nil "neq" "Relational" 8800) ;; #X2260
    (nil "smile" "Relational" 8995) ;; #X2323
    (nil "sqsubseteq" "Relational" 8849) ;; #X2291
    (nil "sqsupseteq" "Relational" 8850) ;; #X2292
    (nil "doteq" "Relational" 8784) ;; #X2250
    (nil "frown" "Relational" 8994) ;; #X2322
    (?i "in" "Relational" 8712) ;; #X2208
    (nil "ni" "Relational" 8715) ;; #X220B
    (nil "propto" "Relational" 8733) ;; #X221D
    (nil "vdash" "Relational" 8866) ;; #X22A2
    (nil "dashv" "Relational" 8867) ;; #X22A3
    (?\C-b "leftarrow" "Arrows" 8592) ;; #X2190
    (nil "Leftarrow" "Arrows" 8656) ;; #X21D0
    (?\C-f "rightarrow" "Arrows" 8594) ;; #X2192
    (nil "Rightarrow" "Arrows" 8658) ;; #X21D2
    (nil "leftrightarrow" "Arrows" 8596) ;; #X2194
    (nil "Leftrightarrow" "Arrows" 8660) ;; #X21D4
    (nil "mapsto" "Arrows" 8614) ;; #X21A6
    (nil "hookleftarrow" "Arrows" 8617) ;; #X21A9
    (nil "leftharpoonup" "Arrows" 8636) ;; #X21BC
    (nil "leftharpoondown" "Arrows" 8637) ;; #X21BD
    (nil "longleftarrow" "Arrows" 10229) ;; #X27F5
    (nil "Longleftarrow" "Arrows" 10232) ;; #X27F8
    (nil "longrightarrow" "Arrows" 10230) ;; #X27F6
    (nil "Longrightarrow" "Arrows" 10233) ;; #X27F9
    (nil "longleftrightarrow" "Arrows" 10231) ;; #X27F7
    (nil "Longleftrightarrow" "Arrows" 10234) ;; #X27FA
    (nil "iff" "Arrows" 10234) ;; #X27FA
    (nil "longmapsto" "Arrows" 10236) ;; #X27FC
    (nil "hookrightarrow" "Arrows" 8618) ;; #X21AA
    (nil "rightharpoonup" "Arrows" 8640) ;; #X21C0
    (nil "rightharpoondown" "Arrows" 8641) ;; #X21C1
    (?\C-p "uparrow" "Arrows" 8593) ;; #X2191
    (nil "Uparrow" "Arrows" 8657) ;; #X21D1
    (?\C-n "downarrow" "Arrows" 8595) ;; #X2193
    (nil "Downarrow" "Arrows" 8659) ;; #X21D3
    (nil "updownarrow" "Arrows" 8597) ;; #X2195
    (nil "Updownarrow" "Arrows" 8661) ;; #X21D5
    (nil "nearrow" "Arrows" 8599) ;; #X2197
    (nil "searrow" "Arrows" 8600) ;; #X2198
    (nil "swarrow" "Arrows" 8601) ;; #X2199
    (nil "nwarrow" "Arrows" 8598) ;; #X2196
    (nil "ldots" "Punctuation" 8230) ;; #X2026
    (nil "cdots" "Punctuation" 8943) ;; #X22EF
    (nil "vdots" "Punctuation" 8942) ;; #X22EE
    (nil "ddots" "Punctuation" 8945) ;; #X22F1
    (?: "colon" "Punctuation" 58) ;; #X003A
    (?N "nabla" "Misc Symbol" 8711) ;; #X2207
    (nil "aleph" "Misc Symbol" 8501) ;; #X2135
    (nil "prime" "Misc Symbol" 8242) ;; #X2032
    (?A "forall" "Misc Symbol" 8704) ;; #X2200
    (?I "infty" "Misc Symbol" 8734) ;; #X221E
    (nil "hbar" "Misc Symbol" 8463) ;; #X210F
    (?0 "emptyset" "Misc Symbol" 8709) ;; #X2205
    (?E "exists" "Misc Symbol" 8707) ;; #X2203
    (nil "surd" "Misc Symbol" 8730) ;; #X221A
    (nil "Box" "Misc Symbol" 9633) ;; #X25A1
    (nil "triangle" "Misc Symbol" 9651) ;; #X25B3
    (nil "Diamond" "Misc Symbol" 9671) ;; #X25C7
    (nil "imath" "Misc Symbol" 120484) ;; #X1D6A4
    (nil "jmath" "Misc Symbol" 120485) ;; #X1D6A5
    (nil "ell" "Misc Symbol" 8467) ;; #X2113
    (nil "neg" "Misc Symbol" 172) ;; #X00AC
    (?/ "not" "Misc Symbol" 824) ;; #X0338
    (nil "top" "Misc Symbol" 8868) ;; #X22A4
    (nil "flat" "Misc Symbol" 9837) ;; #X266D
    (nil "natural" "Misc Symbol" 9838) ;; #X266E
    (nil "sharp" "Misc Symbol" 9839) ;; #X266F
    (nil "wp" "Misc Symbol" 8472) ;; #X2118
    (nil "bot" "Misc Symbol" 8869) ;; #X22A5
    (nil "clubsuit" "Misc Symbol" 9827) ;; #X2663
    (nil "diamondsuit" "Misc Symbol" 9826) ;; #X2662
    (nil "heartsuit" "Misc Symbol" 9825) ;; #X2661
    (nil "spadesuit" "Misc Symbol" 9824) ;; #X2660
    (nil "mho" "Misc Symbol" 8487) ;; #X2127
    (nil "Re" "Misc Symbol" 8476) ;; #X211C
    (nil "Im" "Misc Symbol" 8465) ;; #X2111
    (nil "angle" "Misc Symbol" 8736) ;; #X2220
    (nil "partial" "Misc Symbol" 8706) ;; #X2202
    (nil "sum" "Var Symbol" 8721) ;; #X2211
    (nil "prod" "Var Symbol" 8719) ;; #X220F
    (nil "coprod" "Var Symbol" 8720) ;; #X2210
    (nil "int" "Var Symbol" 8747) ;; #X222B
    (nil "oint" "Var Symbol" 8750) ;; #X222E
    (nil "bigcap" "Var Symbol" 8898) ;; #X22C2
    (nil "bigcup" "Var Symbol" 8899) ;; #X22C3
    (nil "bigsqcup" "Var Symbol" 10758) ;; #X2A06
    (nil "bigvee" "Var Symbol" 8897) ;; #X22C1
    (nil "bigwedge" "Var Symbol" 8896) ;; #X22C0
    (nil "bigodot" "Var Symbol" 10752) ;; #X2A00
    (nil "bigotimes" "Var Symbol" 10754) ;; #X2A02
    (nil "bigoplus" "Var Symbol" 10753) ;; #X2A01
    (nil "biguplus" "Var Symbol" 10756) ;; #X2A04
    (nil "arccos" "Log-like")
    (nil "arcsin" "Log-like")
    (nil "arctan" "Log-like")
    (nil "arg" "Log-like")
    (?\C-c "cos" "Log-like")
    (nil "cosh" "Log-like")
    (nil "cot" "Log-like")
    (nil "coth" "Log-like")
    (nil "csc" "Log-like")
    (nil "deg" "Log-like")
    (?\C-d "det" "Log-like")
    (nil "dim" "Log-like")
    (?\C-e "exp" "Log-like")
    (nil "gcd" "Log-like")
    (nil "hom" "Log-like")
    (?\C-_ "inf" "Log-like")
    (nil "ker" "Log-like")
    (nil "lg" "Log-like")
    (?\C-l "lim" "Log-like")
    (nil "liminf" "Log-like")
    (nil "limsup" "Log-like")
    (nil "ln" "Log-like")
    (nil "log" "Log-like")
    (nil "max" "Log-like")
    (nil "min" "Log-like")
    (nil "Pr" "Log-like")
    (nil "sec" "Log-like")
    (?\C-s "sin" "Log-like")
    (nil "sinh" "Log-like")
    (?\C-^ "sup" "Log-like")
    (?\C-t "tan" "Log-like")
    (nil "tanh" "Log-like")
    (nil "{" "Delimiters" ?{)
    (nil "}" "Delimiters" ?})
    (nil "lfloor" "Delimiters" 8970) ;; #X230A
    (nil "rfloor" "Delimiters" 8971) ;; #X230B
    (nil "lceil" "Delimiters" 8968) ;; #X2308
    (nil "rceil" "Delimiters" 8969) ;; #X2309
    (?\( "langle" "Delimiters" 10216) ;; #X27E8
    (?\) "rangle" "Delimiters" 10217) ;; #X27E9
    (nil "rmoustache" "Delimiters" 9137) ;; #X23B1
    (nil "lmoustache" "Delimiters" 9136) ;; #X23B0
    (nil "rgroup" "Delimiters" 9133) ;; #X23AD
    (nil "lgroup" "Delimiters" 9129) ;; #X23A9
    (nil "backslash" "Delimiters" 92) ;; #X005C
    (nil "|" "Delimiters" 8214) ;; #X2016)
    (nil "arrowvert" "Delimiters")
    (nil "Arrowvert" "Delimiters")
    (nil "bracevert" "Delimiters")
    (nil "widetilde" "Constructs" 771) ;; #X0303
    (nil "widehat" "Constructs" 770) ;; #X0302
    (nil "overleftarrow" "Constructs" 8406) ;; #X20D6
    (nil "overrightarrow" "Constructs")
    (nil "overline" "Constructs" 773) ;; #X0305
    (nil "underline" "Constructs" 818) ;; #X0332
    (nil "overbrace" "Constructs" 65079) ;; #XFE37
    (nil "underbrace" "Constructs" 65080) ;; #XFE38
    (nil "sqrt" "Constructs" 8730) ;; #X221A
    (nil "frac" "Constructs")
    (?^ "hat" "Accents" 770) ;; #X0302
    (nil "acute" "Accents" 769) ;; #X0301
    (nil "bar" "Accents" 772) ;; #X0304
    (nil "dot" "Accents" 775) ;; #X0307
    (nil "breve" "Accents" 774) ;; #X0306
    (nil "check" "Accents" 780) ;; #X030C
    (nil "grave" "Accents" 768) ;; #X0300
    (nil "vec" "Accents" 8407) ;; #X20D7
    (nil "ddot" "Accents" 776) ;; #X0308
    (?~ "tilde" "Accents" 771) ;; #X0303
    (nil "mathring" "Accents" 778) ;; #X030A
    (nil "beth" ("AMS" "Hebrew") 8502) ;; #X2136
    (nil "daleth" ("AMS" "Hebrew") 8504) ;; #X2138
    (nil "gimel" ("AMS" "Hebrew") 8503) ;; #X2137
    (nil "digamma" ("AMS" "Greek Lowercase") 989) ;; #X03DD
    ("v k" "varkappa" ("AMS" "Greek Lowercase") 1008) ;; #X03F0
    ("v G" "varGamma" ("AMS" "Greek Uppercase") 120548) ;; #X1D6E4
    ("v D" "varDelta" ("AMS" "Greek Uppercase") 120549) ;; #X1D6E5
    ("v J" "varTheta" ("AMS" "Greek Uppercase") 120553) ;; #X1D6E9
    ("v L" "varLambda" ("AMS" "Greek Uppercase") 120556) ;; #X1D6EC
    ("v X" "varXi" ("AMS" "Greek Uppercase") 120559) ;; #X1D6EF
    ("v P" "varPi" ("AMS" "Greek Uppercase") 120561) ;; #X1D6F1
    ("v S" "varSigma" ("AMS" "Greek Uppercase") 120564) ;; #X1D6F4
    ("v U" "varUpsilon" ("AMS" "Greek Uppercase") 120566) ;; #X1D6F6
    ("v F" "varPhi" ("AMS" "Greek Uppercase") 120567) ;; #X1D6F7
    ("v Y" "varPsi" ("AMS" "Greek Uppercase") 120569) ;; #X1D6F9
    ("v W" "varOmega" ("AMS" "Greek Uppercase") 120570) ;; #X1D6FA
    (nil "dashrightarrow" ("AMS" "Arrows"))
    (nil "dashleftarrow" ("AMS" "Arrows"))
    (nil "impliedby" ("AMS" "Arrows") 10232) ;; #X27F8
    (nil "implies" ("AMS" "Arrows") 10233) ;; #X27F9
    (nil "leftleftarrows" ("AMS" "Arrows") 8647) ;; #X21C7
    (nil "leftrightarrows" ("AMS" "Arrows") 8646) ;; #X21C6
    (nil "Lleftarrow" ("AMS" "Arrows") 8666) ;; #X21DA
    (nil "twoheadleftarrow" ("AMS" "Arrows") 8606) ;; #X219E
    (nil "leftarrowtail" ("AMS" "Arrows") 8610) ;; #X21A2
    (nil "looparrowleft" ("AMS" "Arrows") 8619) ;; #X21AB
    (nil "leftrightharpoons" ("AMS" "Arrows") 8651) ;; #X21CB
    (nil "curvearrowleft" ("AMS" "Arrows") 8630) ;; #X21B6
    (nil "circlearrowleft" ("AMS" "Arrows") 8634) ;; #X21BA
    (nil "Lsh" ("AMS" "Arrows") 8624) ;; #X21B0
    (nil "upuparrows" ("AMS" "Arrows") 8648) ;; #X21C8
    (nil "upharpoonleft" ("AMS" "Arrows") 8639) ;; #X21BF
    (nil "downharpoonleft" ("AMS" "Arrows") 8643) ;; #X21C3
    (nil "multimap" ("AMS" "Arrows") 8888) ;; #X22B8
    (nil "leftrightsquigarrow" ("AMS" "Arrows") 8621) ;; #X21AD
    (nil "looparrowright" ("AMS" "Arrows") 8620) ;; #X21AC
    (nil "rightleftharpoons" ("AMS" "Arrows") 8652) ;; #X21CC
    (nil "curvearrowright" ("AMS" "Arrows") 8631) ;; #X21B7
    (nil "circlearrowright" ("AMS" "Arrows"))
    (nil "Rsh" ("AMS" "Arrows") 8625) ;; #X21B1
    (nil "downdownarrows" ("AMS" "Arrows") 8650) ;; #X21CA
    (nil "upharpoonright" ("AMS" "Arrows") 8638) ;; #X21BE
    (nil "downharpoonright" ("AMS" "Arrows") 8642) ;; #X21C2
    (nil "rightsquigarrow" ("AMS" "Arrows") 8605) ;; #X219D
    (nil "nleftarrow" ("AMS" "Neg Arrows") 8602) ;; #X219A
    (nil "nrightarrow" ("AMS" "Neg Arrows") 8603) ;; #X219B
    (nil "nLeftarrow" ("AMS" "Neg Arrows") 8653) ;; #X21CD
    (nil "nRightarrow" ("AMS" "Neg Arrows") 8655) ;; #X21CF
    (nil "nleftrightarrow" ("AMS" "Neg Arrows") 8622) ;; #X21AE
    (nil "nLeftrightarrow" ("AMS" "Neg Arrows") 8654) ;; #X21CE
    (nil "leqq" ("AMS" "Relational I") 8806) ;; #X2266
    (nil "leqslant" ("AMS" "Relational I") 10877) ;; #X2A7D
    (nil "eqslantless" ("AMS" "Relational I") 10901) ;; #X2A95
    (nil "lesssim" ("AMS" "Relational I") 8818) ;; #X2272
    (nil "lessapprox" ("AMS" "Relational I") 10885) ;; #X2A85
    (nil "approxeq" ("AMS" "Relational I") 8778) ;; #X224A
    (nil "lessdot" ("AMS" "Relational I") 8918) ;; #X22D6
    (nil "lll" ("AMS" "Relational I") 8920) ;; #X22D8
    (nil "lessgtr" ("AMS" "Relational I") 8822) ;; #X2276
    (nil "lesseqgtr" ("AMS" "Relational I") 8922) ;; #X22DA
    (nil "lesseqqgtr" ("AMS" "Relational I") 10891) ;; #X2A8B
    (nil "doteqdot" ("AMS" "Relational I") 8785) ;; #X2251
    (nil "risingdotseq" ("AMS" "Relational I") 8787) ;; #X2253
    (nil "fallingdotseq" ("AMS" "Relational I") 8786) ;; #X2252
    (nil "backsim" ("AMS" "Relational I") 8765) ;; #X223D
    (nil "backsimeq" ("AMS" "Relational I") 8909) ;; #X22CD
    (nil "subseteqq" ("AMS" "Relational I") 10949) ;; #X2AC5
    (nil "Subset" ("AMS" "Relational I") 8912) ;; #X22D0
    (nil "sqsubset" ("AMS" "Relational I") 8847) ;; #X228F
    (nil "preccurlyeq" ("AMS" "Relational I") 8828) ;; #X227C
    (nil "curlyeqprec" ("AMS" "Relational I") 8926) ;; #X22DE
    (nil "precsim" ("AMS" "Relational I") 8830) ;; #X227E
    (nil "precapprox" ("AMS" "Relational I") 10935) ;; #X2AB7
    (nil "vartriangleleft" ("AMS" "Relational I") 8882) ;; #X22B2
    (nil "trianglelefteq" ("AMS" "Relational I") 8884) ;; #X22B4
    (nil "vDash" ("AMS" "Relational I") 8872) ;; #X22A8
    (nil "Vvdash" ("AMS" "Relational I") 8874) ;; #X22AA
    (nil "smallsmile" ("AMS" "Relational I") 8995) ;; #X2323
    (nil "smallfrown" ("AMS" "Relational I") 8994) ;; #X2322
    (nil "bumpeq" ("AMS" "Relational I") 8783) ;; #X224F
    (nil "Bumpeq" ("AMS" "Relational I") 8782) ;; #X224E
    (nil "geqq" ("AMS" "Relational II") 8807) ;; #X2267
    (nil "geqslant" ("AMS" "Relational II") 10878) ;; #X2A7E
    (nil "eqslantgtr" ("AMS" "Relational II") 10902) ;; #X2A96
    (nil "gtrsim" ("AMS" "Relational II") 8819) ;; #X2273
    (nil "gtrapprox" ("AMS" "Relational II") 10886) ;; #X2A86
    (nil "gtrdot" ("AMS" "Relational II") 8919) ;; #X22D7
    (nil "ggg" ("AMS" "Relational II") 8921) ;; #X22D9
    (nil "gtrless" ("AMS" "Relational II") 8823) ;; #X2277
    (nil "gtreqless" ("AMS" "Relational II") 8923) ;; #X22DB
    (nil "gtreqqless" ("AMS" "Relational II") 10892) ;; #X2A8C
    (nil "eqcirc" ("AMS" "Relational II") 8790) ;; #X2256
    (nil "circeq" ("AMS" "Relational II") 8791) ;; #X2257
    (nil "triangleq" ("AMS" "Relational II") 8796) ;; #X225C
    (nil "thicksim" ("AMS" "Relational II") 8764) ;; #X223C
    (nil "thickapprox" ("AMS" "Relational II") 8776) ;; #X2248
    (nil "supseteqq" ("AMS" "Relational II") 10950) ;; #X2AC6
    (nil "Supset" ("AMS" "Relational II") 8913) ;; #X22D1
    (nil "sqsupset" ("AMS" "Relational II") 8848) ;; #X2290
    (nil "succcurlyeq" ("AMS" "Relational II") 8829) ;; #X227D
    (nil "curlyeqsucc" ("AMS" "Relational II") 8927) ;; #X22DF
    (nil "succsim" ("AMS" "Relational II") 8831) ;; #X227F
    (nil "succapprox" ("AMS" "Relational II") 10936) ;; #X2AB8
    (nil "vartriangleright" ("AMS" "Relational II") 8883) ;; #X22B3
    (nil "trianglerighteq" ("AMS" "Relational II") 8885) ;; #X22B5
    (nil "Vdash" ("AMS" "Relational II") 8873) ;; #X22A9
    (nil "shortmid" ("AMS" "Relational II") 8739) ;; #X2223
    (nil "shortparallel" ("AMS" "Relational II") 8741) ;; #X2225
    (nil "between" ("AMS" "Relational II") 8812) ;; #X226C
    (nil "pitchfork" ("AMS" "Relational II") 8916) ;; #X22D4
    (nil "varpropto" ("AMS" "Relational II") 8733) ;; #X221D
    (nil "blacktriangleleft" ("AMS" "Relational II") 9664) ;; #X25C0
    (nil "therefore" ("AMS" "Relational II") 8756) ;; #X2234
    (nil "backepsilon" ("AMS" "Relational II") 1014) ;; #X03F6
    (nil "blacktriangleright" ("AMS" "Relational II") 9654) ;; #X25B6
    (nil "because" ("AMS" "Relational II") 8757) ;; #X2235
    (nil "nless" ("AMS" "Neg Rel I") 8814) ;; #X226E
    (nil "nleq" ("AMS" "Neg Rel I") 8816) ;; #X2270
    (nil "nleqslant" ("AMS" "Neg Rel I"))
    (nil "nleqq" ("AMS" "Neg Rel I"))
    (nil "lneq" ("AMS" "Neg Rel I") 10887) ;; #X2A87
    (nil "lneqq" ("AMS" "Neg Rel I") 8808) ;; #X2268
    (nil "lvertneqq" ("AMS" "Neg Rel I"))
    (nil "lnsim" ("AMS" "Neg Rel I") 8934) ;; #X22E6
    (nil "lnapprox" ("AMS" "Neg Rel I") 10889) ;; #X2A89
    (nil "nprec" ("AMS" "Neg Rel I") 8832) ;; #X2280
    (nil "npreceq" ("AMS" "Neg Rel I"))
    (nil "precnsim" ("AMS" "Neg Rel I") 8936) ;; #X22E8
    (nil "precnapprox" ("AMS" "Neg Rel I") 10937) ;; #X2AB9
    (nil "nsim" ("AMS" "Neg Rel I") 8769) ;; #X2241
    (nil "nshortmid" ("AMS" "Neg Rel I") 8740) ;; #X2224
    (nil "nmid" ("AMS" "Neg Rel I") 8740) ;; #X2224
    (nil "nvdash" ("AMS" "Neg Rel I") 8876) ;; #X22AC
    (nil "nvDash" ("AMS" "Neg Rel I") 8877) ;; #X22AD
    (nil "ntriangleleft" ("AMS" "Neg Rel I") 8938) ;; #X22EA
    (nil "ntrianglelefteq" ("AMS" "Neg Rel I") 8940) ;; #X22EC
    (nil "nsubseteq" ("AMS" "Neg Rel I") 8840) ;; #X2288
    (nil "subsetneq" ("AMS" "Neg Rel I") 8842) ;; #X228A
    (nil "varsubsetneq" ("AMS" "Neg Rel I"))
    (nil "subsetneqq" ("AMS" "Neg Rel I") 10955) ;; #X2ACB
    (nil "varsubsetneqq" ("AMS" "Neg Rel I"))
    (nil "ngtr" ("AMS" "Neg Rel II") 8815) ;; #X226F
    (nil "ngeq" ("AMS" "Neg Rel II") 8817) ;; #X2271
    (nil "ngeqslant" ("AMS" "Neg Rel II"))
    (nil "ngeqq" ("AMS" "Neg Rel II"))
    (nil "gneq" ("AMS" "Neg Rel II") 10888) ;; #X2A88
    (nil "gneqq" ("AMS" "Neg Rel II") 8809) ;; #X2269
    (nil "gvertneqq" ("AMS" "Neg Rel II"))
    (nil "gnsim" ("AMS" "Neg Rel II") 8935) ;; #X22E7
    (nil "gnapprox" ("AMS" "Neg Rel II") 10890) ;; #X2A8A
    (nil "nsucc" ("AMS" "Neg Rel II") 8833) ;; #X2281
    (nil "nsucceq" ("AMS" "Neg Rel II"))
    (nil "succnsim" ("AMS" "Neg Rel II") 8937) ;; #X22E9
    (nil "succnapprox" ("AMS" "Neg Rel II") 10938) ;; #X2ABA
    (nil "ncong" ("AMS" "Neg Rel II") 8775) ;; #X2247
    (nil "nshortparallel" ("AMS" "Neg Rel II") 8742) ;; #X2226
    (nil "nparallel" ("AMS" "Neg Rel II") 8742) ;; #X2226
    (nil "nvDash" ("AMS" "Neg Rel II") 8877) ;; #X22AD
    (nil "nVDash" ("AMS" "Neg Rel II") 8879) ;; #X22AF
    (nil "ntriangleright" ("AMS" "Neg Rel II") 8939) ;; #X22EB
    (nil "ntrianglerighteq" ("AMS" "Neg Rel II") 8941) ;; #X22ED
    (nil "nsupseteq" ("AMS" "Neg Rel II") 8841) ;; #X2289
    (nil "nsupseteqq" ("AMS" "Neg Rel II"))
    (nil "supsetneq" ("AMS" "Neg Rel II") 8843) ;; #X228B
    (nil "varsupsetneq" ("AMS" "Neg Rel II"))
    (nil "supsetneqq" ("AMS" "Neg Rel II") 10956) ;; #X2ACC
    (nil "varsupsetneqq" ("AMS" "Neg Rel II"))
    (nil "dotplus" ("AMS" "Binary Op") 8724) ;; #X2214
    (nil "smallsetminus" ("AMS" "Binary Op") 8726) ;; #X2216
    (nil "Cap" ("AMS" "Binary Op") 8914) ;; #X22D2
    (nil "Cup" ("AMS" "Binary Op") 8915) ;; #X22D3
    (nil "barwedge" ("AMS" "Binary Op") 8892) ;; #X22BC
    (nil "veebar" ("AMS" "Binary Op") 8891) ;; #X22BB
    (nil "doublebarwedge" ("AMS" "Binary Op") 8966) ;; #X2306
    (nil "boxminus" ("AMS" "Binary Op") 8863) ;; #X229F
    (nil "boxtimes" ("AMS" "Binary Op") 8864) ;; #X22A0
    (nil "boxdot" ("AMS" "Binary Op") 8865) ;; #X22A1
    (nil "boxplus" ("AMS" "Binary Op") 8862) ;; #X229E
    (nil "divideontimes" ("AMS" "Binary Op") 8903) ;; #X22C7
    (nil "ltimes" ("AMS" "Binary Op") 8905) ;; #X22C9
    (nil "rtimes" ("AMS" "Binary Op") 8906) ;; #X22CA
    (nil "leftthreetimes" ("AMS" "Binary Op") 8907) ;; #X22CB
    (nil "rightthreetimes" ("AMS" "Binary Op") 8908) ;; #X22CC
    (nil "curlywedge" ("AMS" "Binary Op") 8911) ;; #X22CF
    (nil "curlyvee" ("AMS" "Binary Op") 8910) ;; #X22CE
    (nil "circleddash" ("AMS" "Binary Op") 8861) ;; #X229D
    (nil "circledast" ("AMS" "Binary Op") 8859) ;; #X229B
    (nil "circledcirc" ("AMS" "Binary Op") 8858) ;; #X229A
    (nil "centerdot" ("AMS" "Binary Op"))
    (nil "intercal" ("AMS" "Binary Op") 8890) ;; #X22BA
    (nil "hbar" ("AMS" "Misc") 8463) ;; #X210F
    (nil "hslash" ("AMS" "Misc") 8463) ;; #X210F
    (nil "vartriangle" ("AMS" "Misc") 9653) ;; #X25B5
    (nil "triangledown" ("AMS" "Misc") 9663) ;; #X25BF
    (nil "square" ("AMS" "Misc") 9633) ;; #X25A1
    (nil "lozenge" ("AMS" "Misc") 9674) ;; #X25CA
    (nil "circledS" ("AMS" "Misc") 9416) ;; #X24C8
    (nil "angle" ("AMS" "Misc") 8736) ;; #X2220
    (nil "measuredangle" ("AMS" "Misc") 8737) ;; #X2221
    (nil "nexists" ("AMS" "Misc") 8708) ;; #X2204
    (nil "mho" ("AMS" "Misc") 8487) ;; #X2127
    (nil "Finv" ("AMS" "Misc") 8498) ;; #X2132
    (nil "Game" ("AMS" "Misc") 8513) ;; #X2141
    (nil "Bbbk" ("AMS" "Misc") 120156) ;; #X1D55C
    (nil "backprime" ("AMS" "Misc") 8245) ;; #X2035
    (nil "varnothing" ("AMS" "Misc") 8709) ;; #X2205
    (nil "blacktriangle" ("AMS" "Misc") 9652) ;; #X25B4
    (nil "blacktriangledown" ("AMS" "Misc") 9662) ;; #X25BE
    (nil "blacksquare" ("AMS" "Misc") 9632) ;; #X25A0
    (nil "blacklozenge" ("AMS" "Misc") 10731) ;; #X29EB
    (nil "bigstar" ("AMS" "Misc") 9733) ;; #X2605
    (nil "sphericalangle" ("AMS" "Misc") 8738) ;; #X2222
    (nil "complement" ("AMS" "Misc") 8705) ;; #X2201
    (nil "eth" ("AMS" "Misc") 240) ;; #X00F0
    (nil "diagup" ("AMS" "Misc") 9585) ;; #X2571
    (nil "diagdown" ("AMS" "Misc") 9586) ;; #X2572
    (nil "dddot" ("AMS" "Accents") 8411) ;; #X20DB
    (nil "ddddot" ("AMS" "Accents") 8412) ;; #X20DC
    (nil "bigl" ("AMS" "Delimiters"))
    (nil "bigr" ("AMS" "Delimiters"))
    (nil "Bigl" ("AMS" "Delimiters"))
    (nil "Bigr" ("AMS" "Delimiters"))
    (nil "biggl" ("AMS" "Delimiters"))
    (nil "biggr" ("AMS" "Delimiters"))
    (nil "Biggl" ("AMS" "Delimiters"))
    (nil "Biggr" ("AMS" "Delimiters"))
    (nil "lvert" ("AMS" "Delimiters"))
    (nil "rvert" ("AMS" "Delimiters"))
    (nil "lVert" ("AMS" "Delimiters"))
    (nil "rVert" ("AMS" "Delimiters"))
    (nil "ulcorner" ("AMS" "Delimiters") 8988) ;; #X231C
    (nil "urcorner" ("AMS" "Delimiters") 8989) ;; #X231D
    (nil "llcorner" ("AMS" "Delimiters") 8990) ;; #X231E
    (nil "lrcorner" ("AMS" "Delimiters") 8991) ;; #X231F
    (nil "nobreakdash" ("AMS" "Special"))
    (nil "leftroot" ("AMS" "Special"))
    (nil "uproot" ("AMS" "Special"))
    (nil "accentedsymbol" ("AMS" "Special"))
    (nil "xleftarrow" ("AMS" "Special"))
    (nil "xrightarrow" ("AMS" "Special"))
    (nil "overset" ("AMS" "Special"))
    (nil "underset" ("AMS" "Special"))
    (nil "dfrac" ("AMS" "Special"))
    (nil "genfrac" ("AMS" "Special"))
    (nil "tfrac" ("AMS" "Special"))
    (nil "binom" ("AMS" "Special"))
    (nil "dbinom" ("AMS" "Special"))
    (nil "tbinom" ("AMS" "Special"))
    (nil "smash" ("AMS" "Special"))
    (nil "eucal" ("AMS" "Special"))
    (nil "boldsymbol" ("AMS" "Special"))
    (nil "text" ("AMS" "Special"))
    (nil "intertext" ("AMS" "Special"))
    (nil "substack" ("AMS" "Special"))
    (nil "subarray" ("AMS" "Special"))
    (nil "sideset" ("AMS" "Special"))
    ;; Wasysym symbols:
    (nil "lhd" ("Wasysym" "Binary Op") 9665) ;; #X22C1
    (nil "LHD" ("Wasysym" "Binary Op") 9664) ;; #X25C0
    (nil "ocircle" ("Wasysym" "Binary Op") 9675) ;; #X25CB
    (nil "rhd" ("Wasysym" "Binary Op") 9655) ;; #X25B7
    (nil "RHD" ("Wasysym" "Binary Op") 9654) ;; #X25B6
    (nil "unlhd" ("Wasysym" "Binary Op") 8884) ;; #X22B4
    (nil "unrhd" ("Wasysym" "Binary Op") 8885) ;; #X22B5
    (nil "apprle" ("Wasysym" "Relational") 8818) ;; #X2272
    (nil "apprge" ("Wasysym" "Relational") 8819) ;; #X2273
    (nil "invneg" ("Wasysym" "Relational") 8976) ;; #X2310
    (nil "Join" ("Wasysym" "Relational") 10781) ;; #X2A1D
    (nil "leadsto" ("Wasysym" "Relational") 10547) ;; #X2933
    (nil "sqsubset" ("Wasysym" "Relational") 8847) ;; #X228f
    (nil "sqsupset" ("Wasysym" "Relational") 8848) ;; #X2290
    (nil "wasypropto" ("Wasysym" "Relational") 8733) ;; #X221D
    (nil "Box" ("Wasysym" "Misc Symbol") 9633) ;; #X25A1
    (nil "Diamond" ("Wasysym" "Misc Symbol") 9671) ;; #X25C7
    (nil "logof" ("Wasysym" "Misc Symbol")))
  "Alist of LaTeX math symbols.

Each entry should be a list with upto four elements, KEY, VALUE,
MENU and CHARACTER, see `LaTeX-math-list' for details.")

(defcustom LaTeX-math-menu-unicode
  (if (or (string-match "\\<GTK\\>" (emacs-version))
          (memq system-type '(darwin windows-nt)))
      t
    nil)
  "Whether the LaTeX menu should try using Unicode for effect."
  :type 'boolean
  :group 'LaTeX-math)

(defvar LaTeX-math-list) ;; Defined further below.

(defun LaTeX-math-initialize ()
  (let ((math (reverse (append LaTeX-math-list LaTeX-math-default)))
        (map LaTeX-math-keymap)
        (unicode LaTeX-math-menu-unicode))
    (while math
      (let* ((entry (car math))
             (key (nth 0 entry))
             (prefix
              (and unicode
                   (nth 3 entry)))
             value menu name)
        (setq math (cdr math))
        (if (and prefix
                 (setq prefix (nth 3 entry)))
            (setq prefix (concat (string prefix) " \\"))
          (setq prefix "\\"))
        (if (listp (cdr entry))
            (setq value (nth 1 entry)
                  menu (nth 2 entry))
          (setq value (cdr entry)
                menu nil))
        (if (stringp value)
            (progn
              (setq name (intern (concat "LaTeX-math-" value)))
              (fset name (lambda (arg) (interactive "*P")
                           (LaTeX-math-insert value arg))))
          (setq name value))
        (if key
            (progn
              (setq key (cond ((numberp key) (char-to-string key))
                              ((stringp key) (read-kbd-macro key))
                              (t (vector key))))
              (define-key map key name)))
        (if menu
            (let ((parent LaTeX-math-menu))
              (if (listp menu)
                  (progn
                    (while (cdr menu)
                      (let ((sub (assoc (car menu) LaTeX-math-menu)))
                        (if sub
                            (setq parent sub)
                          (setcdr parent (cons (list (car menu)) (cdr parent))))
                        (setq menu (cdr menu))))
                    (setq menu (car menu))))
              (let ((sub (assoc menu parent)))
                (if sub
                    (if (stringp value)
                        (setcdr sub (cons (vector (concat prefix value)
                                                  name t)
                                          (cdr sub)))
                      (error "Cannot have multiple special math menu items"))
                  (setcdr parent
                          (cons (if (stringp value)
                                    (list menu (vector (concat prefix value)
                                                       name t))
                                  (vector menu name t))
                                (cdr parent)))))))))
    ;; Make the math prefix char available if it has not been used as a prefix.
    (unless (lookup-key map (LaTeX-math-abbrev-prefix))
      (define-key map (LaTeX-math-abbrev-prefix) #'self-insert-command))))

(defcustom LaTeX-math-list nil
  "Alist of your personal LaTeX math symbols.

Each entry should be a list with up to four elements, KEY, VALUE,
MENU and CHARACTER.

KEY is the key (after `LaTeX-math-abbrev-prefix') to be redefined
in math minor mode.  KEY can be a character (for example ?o) for a
single stroke or a string (for example \"o a\") for a multi-stroke
binding.  If KEY is nil, the symbol has no associated
keystroke (it is available in the menu, though).  Note that
predefined keys in `LaTeX-math-default' cannot be overridden in
this variable.  Currently, only the lowercase letter \\='o\\=' is free
for user customization, more options are available in uppercase
area.

VALUE can be a string with the name of the macro to be inserted,
or a function to be called.  The macro must be given without the
leading backslash.

The third element MENU is the name of the submenu where the
command should be added.  MENU can be either a string (for
example \"greek\"), a list (for example (\"AMS\" \"Delimiters\"))
or nil.  If MENU is nil, no menu item will be created.

The fourth element CHARACTER is a Unicode character position for
menu display.  When nil, no character is shown.

See also `LaTeX-math-menu'."
  :group 'LaTeX-math
  :set (lambda (symbol value)
         (set-default symbol value)
         (LaTeX-math-initialize))
  :type '(repeat (group (choice :tag "Key"
                                (const :tag "none" nil)
                                (choice (character)
                                        (string :tag "Key sequence")))
                        (choice :tag "Value"
                                (string :tag "Macro")
                                (function))
                        (choice :tag "Menu"
                                (string :tag "Top level menu" )
                                (repeat :tag "Submenu"
                                        (string :tag "Menu")))
                        (choice :tag "Unicode character"
                                (const :tag "none" nil)
                                (integer :tag "Number")))))

(defun LaTeX--completion-annotation-from-math-menu (sym)
  "Return a completion annotation for a SYM.
The annotation is usually a unicode representation of the macro
SYM's compiled representation, for example, if SYM is alpha, α
is returned."
  (catch 'found
    (dolist (var (list LaTeX-math-list LaTeX-math-default))
      (dolist (e var)
        (let ((val (cadr e)))
          (when (and (stringp val)
                     (string= val sym))
            (let ((char (nth 3 e)))
              (when char
                (throw 'found
                       (concat " " (char-to-string char)))))))))))

(defvar LaTeX-math-mode-menu)
(define-minor-mode LaTeX-math-mode
  "A minor mode with easy access to TeX math macros.

Easy insertion of LaTeX math symbols.  If you give a prefix argument,
the symbols will be surrounded by dollar signs.  The following
commands are defined:

\\{LaTeX-math-mode-map}"
  :init-value nil
  :lighter nil
  :keymap (list (cons (LaTeX-math-abbrev-prefix) LaTeX-math-keymap))
  (TeX-set-mode-name))
;; FIXME: Is this still necessary?
(defalias 'latex-math-mode #'LaTeX-math-mode)

(easy-menu-define LaTeX-math-mode-menu
  LaTeX-math-mode-map
  "Menu used in math minor mode."
  LaTeX-math-menu)

(defcustom LaTeX-math-insert-function #'TeX-insert-macro
  "Function called with argument STRING to insert \\STRING."
  :group 'LaTeX-math
  :type 'function)

(defun LaTeX-math-insert (string dollar)
  "Insert \\STRING{}.  If DOLLAR is non-nil, put $'s around it.
If `TeX-electric-math' is non-nil wrap that symbols around the
string."
  (let ((active (TeX-active-mark))
        m closer)
    (if (and active (> (point) (mark)))
        (exchange-point-and-mark))
    (when dollar
      (insert (or (car TeX-electric-math) "$"))
      (save-excursion
        (if active (goto-char (mark)))
        ;; Store closer string for later reference.
        (setq closer (or (cdr TeX-electric-math) "$"))
        (insert closer)
        ;; Set temporal marker to decide whether to put the point
        ;; after the math mode closer or not.
        (setq m (point-marker))))
    (funcall LaTeX-math-insert-function string)
    (when dollar
      ;; If the above `LaTeX-math-insert-function' resulted in
      ;; inserting, e.g., a pair of "\langle" and "\rangle" by
      ;; typing "`(", keep the point between them.  Otherwise
      ;; move the point after the math mode closer.
      (if (= m (+ (point) (length closer)))
          (goto-char m))
      ;; Make temporal marker point nowhere not to slow down the
      ;; subsequent editing in the buffer.
      (set-marker m nil))))

(defun LaTeX-math-cal (char dollar)
  "Insert a {\\cal CHAR}.  If DOLLAR is non-nil, put $'s around it.
If `TeX-electric-math' is non-nil wrap that symbols around the
char."
  (interactive "*c\nP")
  (if dollar (insert (or (car TeX-electric-math) "$")))
  (if (member "latex2e" (TeX-style-list))
      (insert "\\mathcal{" (char-to-string char) "}")
    (insert "{\\cal " (char-to-string char) "}"))
  (if dollar (insert (or (cdr TeX-electric-math) "$"))))


;;; Folding

(defcustom LaTeX-fold-macro-spec-list nil
  "List of display strings and macros to fold in LaTeX mode."
  :type '(repeat (group (choice (string :tag "Display String")
                                (integer :tag "Number of argument" :value 1)
                                (function :tag "Function to execute"))
                        (repeat :tag "Macros" (string))))
  :group 'TeX-fold)

(defcustom LaTeX-fold-env-spec-list nil
  "List of display strings and environments to fold in LaTeX mode."
  :type '(repeat (group (choice (string :tag "Display String")
                                (integer :tag "Number of argument" :value 1)
                                (function :tag "Function to execute"))
                        (repeat :tag "Environments" (string))))
  :group 'TeX-fold)

(defcustom LaTeX-fold-math-spec-list
  (delete nil
          (mapcar (lambda (elt)
                    (let ((tex-token (nth 1 elt))
                          (submenu   (nth 2 elt))
                          (unicode   (nth 3 elt))
                          uchar noargp)
                      (when (integerp unicode)
                        (setq uchar unicode))
                      (when (listp submenu) (setq submenu (nth 1 submenu)))
                      (setq noargp
                            (not (string-match
                                  (concat "^" (regexp-opt '("Constructs"
                                                            "Accents")))
                                  submenu)))
                      (when (and (stringp tex-token) (integerp uchar) noargp)
                        `(,(char-to-string uchar) (,tex-token)))))
                  `((nil "to" "" 8594)
                    (nil "gets" "" 8592)
                    ,@LaTeX-math-default)))
  "List of display strings and math macros to fold in LaTeX mode."
  :type '(repeat (group (choice (string :tag "Display String")
                                (integer :tag "Number of argument" :value 1)
                                (function :tag "Function to execute"))
                        (repeat :tag "Math Macros" (string))))
  :group 'TeX-fold)

;;; Narrowing

(defun LaTeX-narrow-to-environment (&optional count)
  "Make text outside current environment invisible.
With optional COUNT keep visible that number of enclosing
environments."
  (interactive "p")
  (setq count (if count (abs count) 1))
  (save-excursion
    (widen)
    (let ((opoint (point))
          beg end)
      (dotimes (_ count) (LaTeX-find-matching-end))
      (setq end (point))
      (goto-char opoint)
      (dotimes (_ count) (LaTeX-find-matching-begin))
      (setq beg (point))
      (narrow-to-region beg end))))
(put 'LaTeX-narrow-to-environment 'disabled t)

;;; Keymap

(defvar LaTeX-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map TeX-mode-map)

    ;; Standard
    (define-key map "\n"      #'reindent-then-newline-and-indent)

    ;; From latex.el
    ;; We now set `fill-paragraph-function' instead.
    ;; (define-key map "\eq"     'LaTeX-fill-paragraph) ;*** Alias
    ;; This key is now used by Emacs for face settings.
    ;; (define-key map "\eg"     'LaTeX-fill-region) ;*** Alias
    ;; We now set `beginning-of-defun-function' and
    ;; `end-of-defun-function' instead.
    ;; (define-key map "\e\C-e"  #'LaTeX-find-matching-end)
    ;; (define-key map "\e\C-a"  #'LaTeX-find-matching-begin)

    (define-key map "\C-c\C-q\C-p" #'LaTeX-fill-paragraph)
    (define-key map "\C-c\C-q\C-r" #'LaTeX-fill-region)
    (define-key map "\C-c\C-q\C-s" #'LaTeX-fill-section)
    (define-key map "\C-c\C-q\C-e" #'LaTeX-fill-environment)

    (define-key map "\C-c\C-z" #'LaTeX-command-section)
    (define-key map "\C-c\M-z" #'LaTeX-command-section-change-level)

    (define-key map "\C-c."    #'LaTeX-mark-environment) ;*** Dubious
    (define-key map "\C-c*"    #'LaTeX-mark-section) ;*** Dubious

    (define-key map "\C-c\C-e" #'LaTeX-environment)
    (define-key map "\C-c\n"   #'LaTeX-insert-item)
    (or (key-binding "\e\r")
        (define-key map "\e\r"    #'LaTeX-insert-item)) ;*** Alias
    (define-key map "\C-c]" #'LaTeX-close-environment)
    (define-key map "\C-c\C-s" #'LaTeX-section)

    (define-key map "\C-c~"    #'LaTeX-math-mode) ;*** Dubious

    (define-key map "-" #'LaTeX-babel-insert-hyphen)
    (define-key map "(" #'LaTeX-insert-left-brace)
    (define-key map "{" #'LaTeX-insert-left-brace)
    (define-key map "[" #'LaTeX-insert-left-brace)

    (define-key map "\C-xne" #'LaTeX-narrow-to-environment)
    map)
  "Keymap used in `LaTeX-mode'.")

(defvar LaTeX-environment-menu-name "Insert Environment  (C-c C-e)")

(defun LaTeX-environment-menu-entry (entry)
  "Create an ENTRY for the environment menu."
  (vector (car entry) (list #'LaTeX-environment-menu (car entry)) t))

(defvar LaTeX-environment-modify-menu-name "Change Environment  (C-u C-c C-e)")

(defun LaTeX-environment-modify-menu-entry (entry)
  "Create an ENTRY for the change environment menu."
  (vector (car entry) (list #'LaTeX-modify-environment (car entry)) t))

(defun LaTeX-section-enable-symbol (level)
  "Symbol used to enable section LEVEL in the menu bar."
  (intern (concat "LaTeX-section-" (int-to-string level) "-enable")))

(defun LaTeX-section-enable (entry)
  "Enable or disable section ENTRY from `LaTeX-section-list'."
  (let* ((level (nth 1 entry))
         (symbol (LaTeX-section-enable-symbol level)))
    (set symbol (or (= level 0) (>= level LaTeX-largest-level)))
    (make-variable-buffer-local symbol)))

(defun LaTeX-section-menu (level)
  "Insert section from menu."
  (let ((LaTeX-section-hook (delq 'LaTeX-section-heading
                                  (copy-sequence LaTeX-section-hook))))
    (LaTeX-section level)))

(defun LaTeX-section-menu-entry (entry)
  "Create an ENTRY for the section menu."
  (let ((enable (LaTeX-section-enable-symbol (nth 1 entry))))
    (vector (car entry) (list #'LaTeX-section-menu (nth 1 entry)) enable)))

(defcustom LaTeX-menu-max-items 25
  "Maximum number of items in the menu for LaTeX environments.
If number of entries in a menu is larger than this value, split menu
into submenus of nearly equal length.  If nil, never split menu into
submenus."
  :group 'LaTeX-environment
  :type '(choice (const :tag "no submenus" nil)
                 (integer)))

(defcustom LaTeX-submenu-name-format "%-12.12s ... %.12s"
  "Format specification of the submenu name.
Used by `LaTeX-split-long-menu' if the number of entries in a menu is
larger than `LaTeX-menu-max-items'.
This string should contain one %s for the name of the first entry and
one %s for the name of the last entry in the submenu.
If the value is a function, it should return the submenu name.  The
function is called with two arguments, the names of the first and
the last entry in the menu."
  :group 'LaTeX-environment
  :type '(choice (string :tag "Format string")
                 (function)))

(defun LaTeX-split-long-menu (menu)
  "Split MENU according to `LaTeX-menu-max-items'."
  (let ((len (length menu)))
    (if (or (null LaTeX-menu-max-items)
            (null (featurep 'lisp-float-type))
            (<= len LaTeX-menu-max-items))
        menu
      ;; Submenu is max 2 entries longer than menu, never shorter, number of
      ;; entries in submenus differ by at most one (with longer submenus first)
      (let* ((outer (floor (sqrt len)))
             (inner (/ len outer))
             (rest (% len outer))
             (result nil))
        (setq menu (reverse menu))
        (while menu
          (let ((in inner)
                (sub nil)
                (to (car menu)))
            (while (> in 0)
              (setq in   (1- in)
                    sub  (cons (car menu) sub)
                    menu (cdr menu)))
            (setq result
                  (cons (cons (if (stringp LaTeX-submenu-name-format)
                                  (format LaTeX-submenu-name-format
                                          (aref (car sub) 0) (aref to 0))
                                (funcall LaTeX-submenu-name-format
                                         (aref (car sub) 0) (aref to 0)))
                              sub)
                        result)
                  rest  (1+ rest))
            (if (= rest outer) (setq inner (1+ inner)))))
        result))))

(defun LaTeX-section-menu-filter (_ignored)
  "Filter function for the section submenu in the mode menu.
The argument IGNORED is not used in any way."
  (TeX-update-style)
  (or LaTeX-section-menu
      (progn
        (setq LaTeX-section-list-changed nil)
        (mapc #'LaTeX-section-enable LaTeX-section-list)
        (setq LaTeX-section-menu
              (mapcar #'LaTeX-section-menu-entry LaTeX-section-list)))))

(defvar-local LaTeX-environment-menu nil)
(defvar-local LaTeX-environment-modify-menu nil)
(defun LaTeX-environment-menu-filter (menu)
  "Filter function for the environment submenus in the mode menu.
The argument MENU is the name of the submenu in concern and
corresponds to the variables `LaTeX-environment-menu-name' and
`LaTeX-environment-modify-menu-name'."
  (TeX-update-style)
  (cond
   ((string= menu LaTeX-environment-menu-name)
    (or LaTeX-environment-menu
        (setq LaTeX-environment-menu
              (LaTeX-split-long-menu
               (mapcar #'LaTeX-environment-menu-entry
                       (LaTeX-environment-list))))))
   ((string= menu LaTeX-environment-modify-menu-name)
    (or LaTeX-environment-modify-menu
        (setq LaTeX-environment-modify-menu
              (LaTeX-split-long-menu
               (mapcar #'LaTeX-environment-modify-menu-entry
                       (LaTeX-environment-list))))))))

(advice-add 'LaTeX-add-environments :after #'LaTeX--invalidate-menus)
(defun LaTeX--invalidate-menus (&rest _)
  "Mark the environment menus as being in need of a refresh."
  (setq LaTeX-environment-menu nil)
  (setq LaTeX-environment-modify-menu nil))

(easy-menu-define LaTeX-mode-command-menu
    LaTeX-mode-map
    "Command menu used in LaTeX mode."
    (TeX-mode-specific-command-menu 'LaTeX-mode))

(easy-menu-define LaTeX-mode-menu
  LaTeX-mode-map
  "Menu used in LaTeX mode."
  `("LaTeX"
    ("Section  (C-c C-s)" :filter LaTeX-section-menu-filter)
    ["Macro..." TeX-insert-macro
     :help "Insert a macro and possibly arguments"]
    ["Complete Macro" TeX-complete-symbol
     :help "Complete the current macro or environment name"]
    ,(list LaTeX-environment-menu-name
           :filter (lambda (_ignored)
                     (LaTeX-environment-menu-filter
                      LaTeX-environment-menu-name)))
    ,(list LaTeX-environment-modify-menu-name
           :filter (lambda (_ignored)
                     (LaTeX-environment-menu-filter
                      LaTeX-environment-modify-menu-name)))
    ["Close Environment" LaTeX-close-environment
     :help "Insert the \\end part of the current environment"]
    ["Item" LaTeX-insert-item
     :help "Insert a new \\item into current environment"]
    "-"
    ("Insert Font"
     ["Emphasize"    (TeX-font nil ?\C-e) :keys "C-c C-f C-e"]
     "-"
     ["Roman"        (TeX-font nil ?\C-r) :keys "C-c C-f C-r"]
     ["Sans Serif"   (TeX-font nil ?\C-f) :keys "C-c C-f C-f"]
     ["Typewriter"   (TeX-font nil ?\C-t) :keys "C-c C-f C-t"]
     "-"
     ["Medium"       (TeX-font nil ?\C-m) :keys "C-c C-f C-m"]
     ["Bold"         (TeX-font nil ?\C-b) :keys "C-c C-f C-b"]
     "-"
     ["Italic"       (TeX-font nil ?\C-i) :keys "C-c C-f C-i"]
     ["Slanted"      (TeX-font nil ?\C-s) :keys "C-c C-f C-s"]
     ["Small Caps"   (TeX-font nil ?\C-c) :keys "C-c C-f C-c"]
     ["Swash"        (TeX-font nil ?\C-w) :keys "C-c C-f C-w"]
     ["Upper Lower"  (TeX-font nil ?\C-l) :keys "C-c C-f C-l"]
     "-"
     ["Calligraphic" (TeX-font nil ?\C-a) :keys "C-c C-f C-a"]
     ["Normal"       (TeX-font nil ?\C-n) :keys "C-c C-f C-n"])
    ("Replace Font"
     ["Emphasize"    (TeX-font  t  ?\C-e) :keys "C-u C-c C-f C-e"]
     "-"
     ["Roman"        (TeX-font  t  ?\C-r) :keys "C-u C-c C-f C-r"]
     ["Sans Serif"   (TeX-font  t  ?\C-f) :keys "C-u C-c C-f C-f"]
     ["Typewriter"   (TeX-font  t  ?\C-t) :keys "C-u C-c C-f C-t"]
     "-"
     ["Medium"       (TeX-font  t  ?\C-m) :keys "C-u C-c C-f C-m"]
     ["Bold"         (TeX-font  t  ?\C-b) :keys "C-u C-c C-f C-b"]
     "-"
     ["Italic"       (TeX-font  t  ?\C-i) :keys "C-u C-c C-f C-i"]
     ["Slanted"      (TeX-font  t  ?\C-s) :keys "C-u C-c C-f C-s"]
     ["Small Caps"   (TeX-font  t  ?\C-c) :keys "C-u C-c C-f C-c"]
     ["Swash"        (TeX-font  t  ?\C-w) :keys "C-u C-c C-f C-w"]
     ["Upper Lower"  (TeX-font  t  ?\C-l) :keys "C-u C-c C-f C-l"]
     "-"
     ["Calligraphic" (TeX-font  t  ?\C-a) :keys "C-u C-c C-f C-a"]
     ["Normal"       (TeX-font  t  ?\C-n) :keys "C-u C-c C-f C-n"])
    ["Delete Font" (TeX-font t ?\C-d) :keys "C-c C-f C-d"]
    "-"
    ["Comment or Uncomment Region"
     comment-or-uncomment-region
     :help "Make the selected region outcommented or active again"]
    ["Comment or Uncomment Paragraph"
     TeX-comment-or-uncomment-paragraph
     :help "Make the current paragraph outcommented or active again"]
    ("Formatting and Marking"
     ["Format Environment" LaTeX-fill-environment
      :help "Fill and indent the current environment"]
     ["Format Paragraph" LaTeX-fill-paragraph
      :help "Fill and ident the current paragraph"]
     ["Format Region" LaTeX-fill-region
      :help "Fill and indent the currently selected region"]
     ["Format Section" LaTeX-fill-section
      :help "Fill and indent the current section"]
     "-"
     ["Mark Environment" LaTeX-mark-environment
      :help "Mark the current environment"]
     ["Mark Section" LaTeX-mark-section
      :help "Mark the current section"]
     "-"
     ["Beginning of Environment" LaTeX-find-matching-begin
      :help "Move point to the beginning of the current environment"]
     ["End of Environment" LaTeX-find-matching-end
      :help "Move point to the end of the current environment"])
    ,TeX-fold-menu
    ["Math Mode" LaTeX-math-mode
     :style toggle :selected LaTeX-math-mode
     :help "Toggle math mode"]
    "-"
    [ "Convert 209 to 2e" LaTeX-209-to-2e
      :visible (member "latex2" (TeX-style-list)) ]
    . ,TeX-common-menu-entries))

(defcustom LaTeX-font-list
  '((?\C-a ""              ""  "\\mathcal{"    "}")
    (?\C-b "\\textbf{"     "}" "\\mathbf{"     "}")
    (?\C-c "\\textsc{"     "}")
    (?\C-e "\\emph{"       "}")
    (?\C-f "\\textsf{"     "}" "\\mathsf{"     "}")
    (?\C-i "\\textit{"     "}" "\\mathit{"     "}")
    (?\C-l "\\textulc{"    "}")
    (?\C-m "\\textmd{"     "}")
    (?\C-n "\\textnormal{" "}" "\\mathnormal{" "}")
    (?\C-r "\\textrm{"     "}" "\\mathrm{"     "}")
    (?\C-s "\\textsl{"     "}" "\\mathbb{"     "}")
    (?\C-t "\\texttt{"     "}" "\\mathtt{"     "}")
    (?\C-u "\\textup{"     "}")
    (?\C-w "\\textsw{"     "}")
    (?\C-d "" "" t))
  "Font commands used with LaTeX2e.  See `TeX-font-list'."
  :group 'LaTeX-macro
  :type '(repeat
          (group
           :value (?\C-a "" "")
           (character :tag "Key")
           (string :tag "Prefix")
           (string :tag "Suffix")
           (option (group
                    :inline t
                    (string :tag "Math Prefix")
                    (string :tag "Math Suffix")))
           (option (sexp :format "Replace\n" :value t)))))


;;; Simple Commands

(defcustom LaTeX-babel-hyphen "\"="
  "String to be used when typing `-'.
This usually is a hyphen alternative or hyphenation aid, like
\"=, \"~ or \"-, provided by babel and the related language style
files.

Set it to an empty string or nil in order to disable this
feature.  Alter `LaTeX-babel-hyphen-language-alist' in case you
want to change the behavior for a specific language only."
  :group 'LaTeX-macro
  :type 'string)

(defcustom LaTeX-babel-hyphen-after-hyphen t
  "Control insertion of hyphen strings.
If non-nil insert normal hyphen on first key press and swap it
with the language-specific hyphen string specified in the
variable `LaTeX-babel-hyphen' on second key press.  If nil do it
the other way round."
  :group 'LaTeX-macro
  :type 'boolean)

(defcustom LaTeX-babel-hyphen-language-alist nil
  "Alist controlling hyphen insertion for specific languages.
It may be used to override the defaults given by `LaTeX-babel-hyphen'
and `LaTeX-babel-hyphen-after-hyphen' respectively.  The first item
in each element is a string specifying the language as set by the
language-specific style file.  The second item is the string to be
used instead of `LaTeX-babel-hyphen'.  The third element is the
value overriding `LaTeX-babel-hyphen-after-hyphen'."
  :group 'LaTeX-macro
  :type '(alist :key-type (string :tag "Language")
                :value-type (group (string :tag "Hyphen string")
                                   (boolean :tag "Insert plain hyphen first"
                                            :value t))))

(defvar-local LaTeX-babel-hyphen-language nil
  "String determining language-specific behavior of hyphen insertion.
It serves as an indicator that the babel hyphenation string
should be used and as a means to find a potential customization
in `LaTeX-babel-hyphen-language-alist' related to the active
language.  It is usually set by language-related style files.")

(defun LaTeX-babel-insert-hyphen (force)
  "Insert a hyphen string.
The string can be either a normal hyphen or the string specified
in `LaTeX-babel-hyphen'.  Whether one or the other is chosen
depends on the value of `LaTeX-babel-hyphen-after-hyphen' and
the buffer context.
If prefix argument FORCE is non-nil, always insert a regular hyphen."
  (interactive "*P")
  (if (or force
          (zerop (length LaTeX-babel-hyphen))
          (not LaTeX-babel-hyphen-language)
          ;; FIXME: It would be nice to check for verbatim constructs in the
          ;; non-font-locking case, but things like `LaTeX-current-environment'
          ;; are rather expensive in large buffers.
          (and (fboundp 'font-latex-faces-present-p)
               (font-latex-faces-present-p '(font-latex-verbatim-face
                                             font-latex-math-face
                                             font-lock-comment-face)))
          (texmathp)
          (TeX-in-comment))
      (call-interactively #'self-insert-command)
    (let* ((lang (assoc LaTeX-babel-hyphen-language
                        LaTeX-babel-hyphen-language-alist))
           (hyphen (if lang (nth 1 lang) LaTeX-babel-hyphen))
           (h-after-h (if lang (nth 2 lang) LaTeX-babel-hyphen-after-hyphen))
           (hyphen-length (length hyphen)))
      (cond
       ;; "= --> -- / -
       ((string= (buffer-substring (max (- (point) hyphen-length) (point-min))
                                   (point))
                 hyphen)
        (if h-after-h
            (progn (delete-char (- hyphen-length))
                   (insert "--"))
          (delete-char (- hyphen-length))
          (call-interactively #'self-insert-command)))
       ;; -- --> [+]-
       ((string= (buffer-substring (max (- (point) 2) (point-min))
                                   (point))
                 "--")
        (call-interactively #'self-insert-command))
       ;; - --> "= / [+]-
       ((eq (char-before) ?-)
        (if h-after-h
            (progn (delete-char -1)
                   (insert hyphen))
          (call-interactively #'self-insert-command)))
       (h-after-h
        (call-interactively #'self-insert-command))
       (t (insert hyphen))))))
;; Cater for Delete Selection mode
(put 'LaTeX-babel-insert-hyphen 'delete-selection t)

(defcustom LaTeX-enable-toolbar t
  "Enable LaTeX tool bar."
  :group 'TeX-tool-bar
  :type 'boolean)

(defun LaTeX-maybe-install-toolbar ()
  "Conditionally install tool bar buttons for LaTeX mode.
Install tool bar if `LaTeX-enable-toolbar' and `tool-bar-mode'
are non-nil."
  (when (and LaTeX-enable-toolbar tool-bar-mode)
    ;; Defined in `tex-bar.el':
    (LaTeX-install-toolbar)))

;;; Error Messages

(defconst LaTeX-error-description-list
  '(("\\(?:Package Preview Error\\|Preview\\):.*" .
     "The `auctex' option to `preview' should not be applied manually.
If you see this error message outside of a preview run, either
you did something too clever, or AUCTeX something too stupid.")

    ("Bad \\\\line or \\\\vector argument.*" .
     "The first argument of a \\line or \\vector command, which specifies the
slope, is illegal.")

    ("Bad math environment delimiter.*" .
     "TeX has found either a math-mode-starting command such as \\[ or \\(
when it is already in math mode, or else a math-mode-ending command
such as \\) or \\] while in LR or paragraph mode.  The problem is caused
by either unmatched math mode delimiters or unbalanced braces.")

    ("Bad use of \\\\\\\\.*" .
     "A \\\\ command appears between paragraphs, where it makes no sense. This
error message occurs when the \\\\ is used in a centering or flushing
environment or else in the scope of a centering or flushing
declaration.")

    ("\\\\begin{[^ ]*} \\(?:on input line [0-9]+ \\)?ended by \\\\end{[^ ]*}." .
     "LaTeX has found an \\end command that doesn't match the corresponding
\\begin command. You probably misspelled the environment name in the
\\end command, have an extra \\begin, or else forgot an \\end.")

    ("Can be used only in preamble." .
     "LaTeX has encountered, after the \\begin{document}, one of the
following commands that should appear only in the preamble:
\\documentclass, \\nofiles, \\includeonly, \\makeindex, or
\\makeglossary.  The error is also caused by an extra \\begin{document}
command.")

    ("Command name [^ ]* already used.*" .
     "You are using \\newcommand, \\newenvironment, \\newlength, \\newsavebox,
or \\newtheorem to define a command or environment name that is
already defined, or \\newcounter to define a counter that already
exists. (Defining an environment named gnu automatically defines the
command \\gnu.) You'll have to choose a new name or, in the case of
\\newcommand or \\newenvironment, switch to the \\renew ...  command.")

    ("Counter too large." .
     "1. Some object that is numbered with letters, probably an item in a
enumerated list, has received a number greater than 26. Either you're
making a very long list or you've been resetting counter values.

2. Footnotes are being ``numbered'' with letters or footnote symbols
and LaTeX has run out of letters or symbols. This is probably caused
by too many \\thanks commands.")

    ("Environment [^ ]* undefined." .
     "LaTeX has encountered a \\begin command for a nonexistent environment.
You probably misspelled the environment name.")

    ("Float(s) lost." .
     "You put a figure or table environment or a \\marginpar command inside a
parbox---either one made with a minipage environment or \\parbox
command, or one constructed by LaTeX in making a footnote, figure,
etc. This is an outputting error, and the offending environment or
command may be quite a way back from the point where LaTeX discovered
the problem. One or more figures, tables, and/or marginal notes have
been lost, but not necessarily the one that caused the error.")

    ("Illegal character in array arg." .
     "There is an illegal character in the argument of an array or tabular
environment, or in the second argument of a \\multicolumn command.")

    ("Missing \\\\begin{document}." .
     "LaTeX produced printed output before encountering a \\begin{document}
command. Either you forgot the \\begin{document} command or there is
something wrong in the preamble. The problem may be a stray character
or an error in a declaration---for example, omitting the braces around
an argument or forgetting the \\ in a command name.")

    ("Missing p-arg in array arg.*" .
     "There is a p that is not followed by an expression in braces in the
argument of an array or tabular environment, or in the second argument
of a \\multicolumn command.")

    ("Missing @-exp in array arg." .
     "There is an @ character not followed by an @-expression in the
argument of an array or tabular environment, or in the second argument
of a \\multicolumn command.")

    ("No such counter." .
     "You have specified a nonexistent counter in a \\setcounter or
\\addtocounter command. This is probably caused by a simple typing
error.  However, if the error occurred while a file with the extension
aux is being read, then you probably used a \\newcounter command
outside the preamble.")

    ("Not in outer par mode." .
     "You had a figure or table environment or a \\marginpar command in math
mode or inside a parbox.")

    ("\\\\pushtabs and \\\\poptabs don't match." .
     "LaTeX found a \\poptabs with no matching \\pushtabs, or has come to the
\\end{tabbing} command with one or more unmatched \\pushtabs commands.")

    ("Something's wrong--perhaps a missing \\\\item." .
     "The most probable cause is an omitted \\item command in a list-making
environment. It is also caused by forgetting the argument of a
thebibliography environment.")

    ("Tab overflow." .
     "A \\= command has exceeded the maximum number of tab stops that LaTeX
permits.")

    ("There's no line here to end." .
     "A \\newline or \\\\ command appears between paragraphs, where it makes no
sense. If you're trying to ``leave a blank line'', use a \\vspace
command.")

    ("This may be a LaTeX bug." .
     "LaTeX has become thoroughly confused. This is probably due to a
previously detected error, but it is possible that you have found an
error in LaTeX itself. If this is the first error message produced by
the input file and you can't find anything wrong, save the file and
contact the person listed in your Local Guide.")

    ("Too deeply nested." .
     "There are too many list-making environments nested within one another.
How many levels of nesting are permitted may depend upon what computer
you are using, but at least four levels are provided, which should be
enough.")

    ("Too many unprocessed floats." .
     "While this error can result from having too many \\marginpar commands
on a page, a more likely cause is forcing LaTeX to save more figures
and tables than it has room for.  When typesetting its continuous
scroll, LaTeX saves figures and tables separately and inserts them as
it cuts off pages. This error occurs when LaTeX finds too many figure
and/or table environments before it is time to cut off a page, a
problem that is solved by moving some of the environments farther
towards the end of the input file. The error can also be caused by a
``logjam''---a figure or table that cannot be printed causing others
to pile up behind it, since LaTeX will not print figures or tables out
of order. The jam can be started by a figure or table that either is
too large to fit on a page or won't fit where its optional placement
argument says it must go. This is likely to happen if the argument
does not contain a p option.")

    ("Undefined tab position." .
     "A \\>, \\+, \\-, or \\< command is trying to go to a nonexistent tab
position---one not defined by a \\= command.")

    ("\\\\< in mid line." .
     "A \\< command appears in the middle of a line in a tabbing environment.
This command should come only at the beginning of a line.")

    ("Double subscript." .
     "There are two subscripts in a row in a mathematical
formula---something like x_{2}_{3}, which makes no sense.")

    ("Double superscript." .
     "There are two superscripts in a row in a mathematical
formula---something like x^{2}^{3}, which makes no sense.")

    ("Extra alignment tab has been changed to \\\\cr." .
     "There are too many separate items (column entries) in a single row of
an array or tabular environment. In other words, there were too many &
's before the end of the row. You probably forgot the \\\\ at the end of
the preceding row.")

    ("Extra \\}, or forgotten \\$." .
     "The braces or math mode delimiters don't match properly. You probably
forgot a {, \\[, \\(, or $.")

    ("Font [^ ]* not loaded: Not enough room left." .
     "The document uses more fonts than TeX has room for. If different parts
of the document use different fonts, then you can get around the
problem by processing it in parts.")

    ("I can't find file `.*'." .
     "TeX can't find a file that it needs. If the name of the missing file
has the extension tex, then it is looking for an input file that you
specified---either your main file or another file inserted with an
\\input or \\include command. If the missing file has the extension sty
, then you have specified a nonexistent document style or style
option.")

    ("Illegal parameter number in definition of .*" .
     "This is probably caused by a \\newcommand, \\renewcommand,
\\newenvironment, or \\renewenvironment command in which a # is used
incorrectly.  A # character, except as part of the command name \\#,
can be used only to indicate an argument parameter, as in #2, which
denotes the second argument. This error is also caused by nesting one
of the above four commands inside another, or by putting a parameter
like #2 in the last argument of a \\newenvironment or \\renewenvironment
command.")

    ("Illegal unit of measure ([^ ]* inserted)." .
     "If you just got a

      ! Missing number, treated as zero.

error, then this is part of the same problem.  If not, it means that
LaTeX was expecting a length as an argument and found a number
instead.  The most common cause of this error is writing 0 instead of
something like 0in for a length of zero, in which case typing return
should result in correct output. However, the error can also be caused
by omitting a command argument.")

    ("Misplaced alignment tab character \\&." .
     "The special character &, which should be used only to separate items
in an array or tabular environment, appeared in ordinary text. You
probably meant to type \\&.")

    ("Missing control sequence inserted." .
     "This is probably caused by a \\newcommand, \\renewcommand, \\newlength,
or \\newsavebox command whose first argument is not a command name.")

    ("Missing number, treated as zero." .
     "This is usually caused by a LaTeX command expecting but not finding
either a number or a length as an argument. You may have omitted an
argument, or a square bracket in the text may have been mistaken for
the beginning of an optional argument. This error is also caused by
putting \\protect in front of either a length command or a command such
as \\value that produces a number.")

    ("Missing [{}] inserted." .
     "TeX has become confused. The position indicated by the error locator
is probably beyond the point where the incorrect input is.")

    ("Missing \\$ inserted." .
     "TeX probably found a command that can be used only in math mode when
it wasn't in math mode.  Remember that unless stated otherwise, all
all the commands of Section 3.3 in LaTeX Book (Lamport) can be used
only in math mode. TeX is not in math mode when it begins processing
the argument of a box-making command, even if that command is inside a
math environment. This error also occurs if TeX encounters a blank
line when it is in math mode.")

    ("Not a letter." .
     "Something appears in the argument of a \\hyphenation command that
doesn't belong there.")

    ("Paragraph ended before [^ ]* was complete." .
     "A blank line occurred in a command argument that shouldn't contain
one. You probably forgot the right brace at the end of an argument.")

    ("\\\\[^ ]*font [^ ]* is undefined .*" .
     "These errors occur when an uncommon font is used in math mode---for
example, if you use a \\sc command in a formula inside a footnote,
calling for a footnote-sized small caps font.  This problem is solved
by using a \\load command.")

    ("Font .* not found." .
     "You requested a family/series/shape/size combination that is totally
unknown.  There are two cases in which this error can occur:
  1) You used the \\size macro to select a size that is not available.
  2) If you did not do that, go to your local `wizard' and
     complain fiercely that the font selection tables are corrupted!")

    ("TeX capacity exceeded, sorry .*" .
     "TeX has just run out of space and aborted its execution. Before you
panic, remember that the least likely cause of this error is TeX not
having the capacity to process your document.  It was probably an
error in your input file that caused TeX to run out of room. The
following discussion explains how to decide whether you've really
exceeded TeX's capacity and, if so, what to do. If the problem is an
error in the input, you may have to use the divide and conquer method
described previously to locate it. LaTeX seldom runs out of space on a
short input file, so if running it on the last few pages before the
error indicator's position still produces the error, then there's
almost certainly something wrong in the input file.

The end of the error indicator tells what kind of space TeX ran out
of. The more common ones are listed below, with an explanation of
their probable causes.

buffer size
===========
Can be caused by too long a piece of text as the argument
of a sectioning, \\caption, \\addcontentsline, or \\addtocontents
command. This error will probably occur when the \\end{document} is
being processed, but it could happen when a \\tableofcontents,
\\listoffigures, or \\listoftables command is executed. To solve this
problem, use a shorter optional argument. Even if you're producing a
table of contents or a list of figures or tables, such a long entry
won't help the reader.

exception dictionary
====================
You have used \\hyphenation commands to give TeX
more hyphenation information than it has room for. Remove some of the
less frequently used words from the \\hyphenation commands and insert
\\- commands instead.

hash size
=========
Your input file defines too many command names and/or uses
too many cross-ref- erencing labels.

input stack size
================
This is probably caused by an error in a command
definition. For example, the following command makes a circular
definition, defining \\gnu in terms of itself:

          \\newcommand{\\gnu}{a \\gnu} % This is wrong!

When TeX encounters this \\gnu command, it will keep chasing its tail
trying to figure out what \\gnu should produce, and eventually run out
of ``input stack''.

main memory size
================
This is one kind of space that TeX can run out of when processing a
short file. There are three ways you can run TeX out of main memory
space: (1) defining a lot of very long, complicated commands, (2)
making an index or glossary and having too many \\index or \\glossary
commands on a single page, and (3) creating so complicated a page of
output that TeX can't hold all the information needed to generate it.
The solution to the first two problems is obvious: define fewer
commands or use fewer \\index and \\glossary commands. The third problem
is nastier. It can be caused by large tabbing, tabular, array, and
picture environments. TeX's space may also be filled up with figures
and tables waiting for a place to go.  To find out if you've really
exceeded TeX's capacity in this way, put a \\clearpage command in your
input file right before the place where TeX ran out of room and try
running it again. If it doesn't run out of room with the \\clearpage
command there, then you did exceed TeX's capacity.  If it still runs
out of room, then there's probably an error in your file.  If TeX is
really out of room, you must give it some help. Remember that TeX
processes a complete paragraph before deciding whether to cut the
page. Inserting a \\newpage command in the middle of the paragraph,
where TeX should break the page, may save the day by letting TeX write
the current page before processing the rest of the paragraph. (A
\\pagebreak command won't help.) If the problem is caused by
accumulated figures and tables, you can try to prevent them from
accumulating---either by moving them further towards the end of the
document or by trying to get them to come out sooner.  If you are
still writing the document, simply add a \\clearpage command and forget
about the problem until you're ready to produce the final version.
Changes to the input file are likely to make the problem go away.

pool size
=========
You probably used too many cross-ref-erencing \\labels and/or defined
too many new command names. More precisely, the labels and command
names that you define have too many characters, so this problem can be
solved by using shorter names. However, the error can also be caused
by omitting the right brace that ends the argument of either a counter
command such as \\setcounter, or a \\newenvironment or \\newtheorem
command.

save size
=========
This occurs when commands, environments, and the scopes of
declarations are nested too deeply---for example, by having the
argument of a \\multiput command contain a picture environment that in
turn has a \\footnotesize declaration whose scope contains a \\multiput
command containing a ....")

    ("Text line contains an invalid character." .
     "The input contains some strange character that it shouldn't. A mistake
when creating the file probably caused your text editor to insert this
character. Exactly what could have happened depends upon what text
editor you used. If examining the input file doesn't reveal the
offending character, consult the Local Guide for suggestions.")

    ("Undefined control sequence."   .
     "TeX encountered an unknown command name. You probably misspelled the
name. If this message occurs when a LaTeX command is being processed,
the command is probably in the wrong place---for example, the error
can be produced by an \\item command that's not inside a list-making
environment. The error can also be caused by a missing \\documentclass
command.")

    ("Use of [^ ]* doesn't match its definition." .
     "It's probably one of the picture-drawing commands, and you have used
the wrong syntax for specifying an argument. If it's \\@array that
doesn't match its definition, then there is something wrong in an
@-expression in the argument of an array or tabular
environment---perhaps a fragile command that is not \\protect'ed.")

    ("You can't use `macro parameter character \\#' in [^ ]* mode." .
     "The special character # has appeared in ordinary text. You probably
meant to type \\#.")

    ("Overfull \\\\hbox .*" .
     "Because it couldn't find a good place for a line break, TeX put more
on this line than it should.")

    ("Overfull \\\\vbox .*" .
     "Because it couldn't find a good place for a page break, TeX put more
on the page than it should.")

    ("Underfull \\\\hbox .*" .
     "Check your output for extra vertical space.  If you find some, it was
probably caused by a problem with a \\\\ or \\newline command---for
example, two \\\\ commands in succession. This warning can also be
caused by using the sloppypar environment or \\sloppy declaration, or
by inserting a \\linebreak command.")

    ("Underfull \\\\vbox .*" .
     "TeX could not find a good place to break the page, so it produced a
page without enough text on it.")

    ;; New list items should be placed here
    ;;
    ;; ("err-regexp" . "context")
    ;;
    ;; the err-regexp item should match anything

    (".*" . "No help available"))       ; end definition
  "Help messages for errors in LaTeX mode.
Used as buffer local value of `TeX-error-description-list-local'.
See its doc string for detail.")


;;; LaTeX Capf for macro/environment arguments:

;; tex.el defines the function `TeX--completion-at-point' which
;; provides completion at point for (La)TeX macros.  Here we define
;; `LaTeX--arguments-completion-at-point' which is the entry point for
;; completion at point when inside a macro or environment argument.
;; The general idea is:
;;
;; - Find out in which argument of macro/env the point is; this is
;; done by the function `LaTeX-what-macro'.
;;
;; - Match the result against the information available in
;; `TeX-symbol-list' or `LaTeX-environment-list' by the function
;; `LaTeX-completion-parse-args'.
;;
;; - If there is a match, pass it to `LaTeX-completion-parse-arg'
;; (note the missing `s') which parses the match and runs the
;; corresponding function to calculate the candidates.  These are the
;; functions `LaTeX-completion-candidates-key-val',
;; `LaTeX-completion-candidates-completing-read-multiple', and
;; `LaTeX-completion-candidates-completing-read'.
;;
;; Two mapping variables `LaTeX-completion-function-map-alist-keyval'
;; and `LaTeX-completion-function-map-alist-cr' are provided in order
;; to allow a redirection of the entry in `TeX-symbol-list' or
;; `LaTeX-environment-list' to another function.

(defvar LaTeX-completion-macro-delimiters
  '((?\[ . ?\])
    (?\{ . ?\})
    (?\( . ?\))
    (?\< . ?\>))
  "List of characters delimiting mandatory and optional arguments.
Each element in the list is cons with opening char as car and the
closing char as cdr.")

(defun LaTeX-completion-macro-delimiters (&optional which)
  "Return elements of the variable `LaTeX-completion-macro-delimiters'.
If the optional WHICH is the symbol `open', return the car's of
each element in the variable `LaTeX-completion-macro-delimiters'.
If it is the symbol `close', return the cdr's.  If omitted or
nil, return all elements."
  (cond ((eq which 'open)
         (mapcar #'car LaTeX-completion-macro-delimiters))
        ((eq which 'close)
         (mapcar #'cdr LaTeX-completion-macro-delimiters))
        (t
         (append
          (mapcar #'car LaTeX-completion-macro-delimiters)
          (mapcar #'cdr LaTeX-completion-macro-delimiters)))))

(defun LaTeX-move-to-previous-arg (&optional bound)
  "Move backward to the closing parenthesis of the previous argument.
Closing parenthesis is in this context all characters which can
be used to delimit an argument.  Currently, these are the
following characters:

  } ] ) >

This happens under the assumption that we are in front of a macro
argument.  This function understands the splitting of macros over
several lines in TeX."
  (cond
   ;; Just to be quick:
   ((memql (preceding-char) (LaTeX-completion-macro-delimiters 'close)))
   ;; Do a search:
   ((re-search-backward
     "[]})>][ \t]*[\n\r]?\\([ \t]*%[^\n\r]*[\n\r]\\)*[ \t]*\\=" bound t)
    (goto-char (1+ (match-beginning 0)))
    t)
   (t nil)))

(defun LaTeX-what-macro (&optional bound)
  "Find out if point is within the arguments of any TeX-macro.
The return value is

  (\"name\" mac-or-env total-num type opt-num opt-distance)

\"name\" is the name of the macro (without backslash) or
  environment as a string.
mac-or-env is one of the symbols `mac' or `env'.
total-num is the total number of the argument before the point started.
type is one of the symbols `mandatory' or `optional'.
opt-num is the number of optional arguments before the point started.
opt-distance the number of optional arguments after the last mandatory.

If the optional BOUND is an integer, limit backward searches to
this point.  If nil, limit to the previous 15 lines."
  (let ((bound (or bound (line-beginning-position -15)))
        (env-or-mac 'mac)
        cmd cnt cnt-opt type result ;; env-or-mac-start
        (cnt-distance 0))
    (save-excursion
      (save-restriction
        (narrow-to-region (max (point-min) bound) (point-max))
        ;; Move back out of the current parenthesis
        (with-syntax-table (apply #'TeX-search-syntax-table
                                  (LaTeX-completion-macro-delimiters))
          (condition-case nil
              (let ((forward-sexp-function nil))
                (up-list -1))
            (error nil))
          ;; Set the initial value of argument counter
          (setq cnt 1)
          ;; Note that we count also the right opt. or man. arg and
          ;; record if we're inside a mand. or opt. argument
          (if (= (following-char) ?\{)
              (setq cnt-opt 0
                    type 'mandatory)
            (setq cnt-opt 1
                  type 'optional))
          ;; Move back over any touching sexps
          (while (and (LaTeX-move-to-previous-arg bound)
                      (condition-case nil
                          (let ((forward-sexp-function nil))
                            (backward-sexp) t)
                        (error nil)))
            (unless (= (following-char) ?\{)
              (cl-incf cnt-opt))
            (cl-incf cnt)))
        ;; (setq env-or-mac-start (point))
        (when (and (memql (following-char) ;; '(?\[ ?\{ ?\( ?<)
                          (LaTeX-completion-macro-delimiters 'open))
                   (re-search-backward "\\\\[*+a-zA-Z]+\\=" nil t))
          (setq cmd (TeX-match-buffer 0))
          (when (looking-at "\\\\begin{\\([^}]+\\)}")
            (setq cmd (TeX-match-buffer 1))
            (setq env-or-mac 'env)
            (cl-decf cnt))
          (when (and cmd (not (string= cmd "")))
            (setq result (list (if (eq env-or-mac 'mac)
                                   ;; Strip leading backslash from
                                   ;; the macro
                                   (substring cmd 1)
                                 cmd)
                               env-or-mac cnt type cnt-opt))))))
    ;; If we were inside an optional argument after a mandatory one,
    ;; we have to find out the number of optional arguments before
    ;; the mandatory one.
    (when (and (eq (nth 3 result) 'optional)
               (/= 0 (- (nth 2 result) (nth 4 result))))
      (save-excursion
        (save-restriction
          (narrow-to-region (max (point-min) bound) (point-max))
          (with-syntax-table (apply #'TeX-search-syntax-table
                                    (LaTeX-completion-macro-delimiters))
            (let ((forward-sexp-function nil))
              (up-list -1))
            (unless (= (following-char) ?\{)
              (cl-incf cnt-distance))
            (while (and (LaTeX-move-to-previous-arg bound)
                        (condition-case nil
                            (let ((forward-sexp-function nil))
                              (backward-sexp)
                              (/= (following-char) ?\{))
                          (error nil)))
              (cl-incf cnt-distance))))))
    ;; Check if we really have a result before adding something new:
    (when result
      (append result (list cnt-distance)))))

(defun LaTeX-completion-candidates-key-val (key-vals)
  "Return completion candidates from KEY-VALS based on buffer position.
KEY-VALS is an alist of key-values pairs."
  (let ((end (point))
        (func (lambda (kv &optional k)
                (if k
                    (cadr (assoc k kv))
                  kv)))
        beg key)
    (save-excursion
      (re-search-backward "[[{(<,=]" (line-beginning-position 0) t))
    (if (string= (match-string 0) "=")
        ;; We have to look for a value:
        (save-excursion
          ;; Matching the value is easy, just grab everything before the
          ;; '=' and ...
          (re-search-backward "=\\([^=]*\\)" (line-beginning-position) t)
          ;; ... then move forward over any tabs and spaces:
          (save-excursion
            (forward-char)
            (skip-chars-forward " \t" end)
            (setq beg (point)))
          ;; Matching the key is less fun: `re-search-backward'
          ;; doesn't travel enough, so we have to use
          ;; `skip-chars-backward' and limit the search to the
          ;; beginning of the previous line:
          (skip-chars-backward "^,[{<" (line-beginning-position 0))
          ;; Make sure we're not looking at a comment:
          (when (looking-at-p (concat "[ \t]*" TeX-comment-start-regexp))
            (forward-line))
          ;; Now pick up the key, if available:
          (setq key (string-trim
                     (buffer-substring-no-properties (point)
                                                     (match-beginning 0))
                     "[ \t\n\r%]+" "[ \t\n\r%]+"))
          ;; This caters also for the case where nothing is typed yet:
          (list beg end (completion-table-dynamic
                         (lambda (_)
                           (funcall func key-vals key)))))
      ;; We have to look for a key:
      (save-excursion
        ;; Find the beginning
        (skip-chars-backward "^,[{<" (line-beginning-position 0))
        ;; Make sure we're not looking at a comment:
        (when (looking-at-p (concat "[ \t]*" TeX-comment-start-regexp))
          (forward-line))
        ;; Now go until the first char or number which would be the
        ;; start of the key:
        (skip-chars-forward "^a-zA-Z0-9" end)
        (setq beg (point))
        ;; This caters also for the case where nothing is typed yet:
        (list beg end (completion-table-dynamic
                       (lambda (_)
                         (funcall func key-vals))))))))

(defun LaTeX-completion-candidates-completing-read-multiple (collection)
  "Return completion candidates from COLLECTION based on buffer position.
COLLECTION is an list of strings."
  (let ((end (point))
        beg list-beg)
    (save-excursion
      (with-syntax-table (apply #'TeX-search-syntax-table
                                (LaTeX-completion-macro-delimiters))
        (up-list -1))
      (setq list-beg (1+ (point))))
    (save-excursion
      (unless (search-backward "," list-beg t)
        (goto-char list-beg))
      (skip-chars-forward "^a-zA-Z0-9" end)
      (setq beg (point)))
    (list beg end (completion-table-dynamic
                   (lambda (_)
                     collection)))))

(defun LaTeX-completion-candidates-completing-read (collection)
  "Return completion candidates from COLLECTION based on buffer position.
COLLECTION is an list of strings."
  (let ((end (point))
        beg)
    (save-excursion
      (with-syntax-table (apply #'TeX-search-syntax-table
                                (LaTeX-completion-macro-delimiters))
        (up-list -1))
      (forward-char)
      (skip-chars-forward "^a-zA-Z0-9" end)
      (setq beg (point)))
    (list beg end (completion-table-dynamic
                   (lambda (_)
                     collection)))))

(defun LaTeX-completion-documentclass-usepackage (entry)
  "Return completion candidates for \\usepackage and \\documentclass arguments.
ENTRY is the value returned by `LaTeX-what-macro'.  This function
provides completion for class/package names if point is inside
the mandatory argument and class/package options if inside the
first optional argument.  The completion for class/package names
is provided only if the value of `TeX-arg-input-file-search' is
set to t."
  (let ((cls-or-sty (if (member (car entry) '("usepackage" "RequirePackage"
                                              "RequirePackageWithOptions"))
                        'sty
                      'cls)))
    (cond ((and (eq (nth 3 entry) 'mandatory)
                (eq TeX-arg-input-file-search t))
           (if (eq cls-or-sty 'cls)
               (progn
                 (unless LaTeX-global-class-files
                   (let ((TeX-file-extensions '("cls")))
                     (message "Searching for LaTeX classes...")
                     (setq LaTeX-global-class-files
                           (mapcar #'list (TeX-search-files-by-type 'texinputs 'global t t)))
                     (message "Searching for LaTeX classes...done")))
                 (LaTeX-completion-candidates-completing-read
                  LaTeX-global-class-files))
             (unless LaTeX-global-package-files
               (let ((TeX-file-extensions '("sty")))
                 (message "Searching for LaTeX packages...")
                 (setq LaTeX-global-package-files
                       (mapcar #'list (TeX-search-files-by-type 'texinputs 'global t t)))
                 (message "Searching for LaTeX packages...done")))
             (LaTeX-completion-candidates-completing-read-multiple
              LaTeX-global-package-files)))
          ;; We have to be more careful for the optional argument
          ;; since the macros can look like this:
          ;; \usepackage[opt1]{mand}[opt2].  So we add an extra check
          ;; if we are inside the first optional arg:
          ((and (eq (nth 3 entry) 'optional)
                (= (nth 2 entry) 1))
           (let ((syntax (TeX-search-syntax-table ?\[ ?\]))
                 style style-opts)
             ;; We have to find out about the package/class name:
             (save-excursion
               (with-syntax-table syntax
                 (condition-case nil
                     (let ((forward-sexp-function nil))
                       (up-list))
                   (error nil)))
               (skip-chars-forward "^[:alnum:]")
               (setq style (thing-at-point 'symbol t)))
             ;; Load the style file; may fail but that's Ok for us
             (TeX-load-style style)
             ;; Now we have to find out how the options are available:
             ;; This is usually a variable called
             ;; `LaTeX-<class|package>-package-options'.  If it is a
             ;; function, then the options are stored either in a
             ;; variable or a function called
             ;; `LaTeX-<class|package>-package-options-list:'
             (when (setq style-opts
                         (intern-soft (format
                                       (concat "LaTeX-%s-"
                                               (if (eq cls-or-sty 'cls)
                                                   "class"
                                                 "package")
                                               "-options")
                                       style)))
               (cond ((and (boundp style-opts)
                           (symbol-value style-opts))
                      (LaTeX-completion-candidates-completing-read-multiple
                       (symbol-value style-opts)))
                     ((and (setq style-opts
                                 (intern-soft (format
                                               (concat "LaTeX-%s-"
                                                       (if (eq cls-or-sty 'cls)
                                                           "class"
                                                         "package")
                                                       "-options-list")
                                               style)))
                           (boundp style-opts)
                           (symbol-value style-opts))
                      (LaTeX-completion-candidates-key-val
                       (symbol-value style-opts)))
                     ((fboundp style-opts)
                      (LaTeX-completion-candidates-key-val
                       (funcall style-opts)))
                     (t nil)))))
          (t nil))))

(defun LaTeX-completion-parse-args (entry)
  "Return the match of buffer position ENTRY with AUCTeX macro definitions.
ENTRY is generated by the function `LaTeX-what-macro'.  This
function matches the current buffer position (that is, which macro
argument) with the corresponding definition in `TeX-symbol-list'
or `LaTeX-environment-list' and returns it."
  (let* ((name (nth 0 entry))
         (mac-or-env (nth 1 entry))
         (total-num (nth 2 entry))
         (type (nth 3 entry))
         (opt-num (nth 4 entry))
         (opt-dis (nth 5 entry))
         (mand-num (- total-num opt-num))
         (cnt 0)
         (again t)
         arg-list
         arg
         result)
    (setq arg-list (cdr (assoc name (if (eq mac-or-env 'mac)
                                        (TeX-symbol-list)
                                      (LaTeX-environment-list)))))

    ;; Check if there is a `LaTeX-env-*-args' in the `arg-list' and
    ;; remove it:
    (when (and (eq mac-or-env 'env)
               (memq (car arg-list) '(LaTeX-env-args
                                      LaTeX-env-item-args
                                      LaTeX-env-label-args)))
      (pop arg-list))

    ;; Check for `TeX-arg-conditional' here and change `arg-list'
    ;; accordingly.
    ;; FIXME: Turn `y-or-n-p' into `always' otherwise there will be a
    ;; query during in-buffer completion.  This will work for most
    ;; cases, but will also fail for example in hyperref.el.  This
    ;; decision should revisited at a later stage:
    (when (assq 'TeX-arg-conditional arg-list)
      (cl-letf (((symbol-function 'y-or-n-p) #'TeX-always))
        (while (and arg-list
                    (setq arg (car arg-list)))
          (if (and (listp arg) (eq (car arg) 'TeX-arg-conditional))
              (setq result (append (reverse (if (eval (nth 1 arg) t)
                                                (nth 2 arg)
                                              (nth 3 arg)))
                                   result))
            (push arg result))
          (pop arg-list)))
      (setq arg-list (nreverse result)))

    ;; Now parse the `arg-list':
    (cond ((and (eq type 'optional)
                (= opt-dis 0))
           ;; Optional arg without mandatory one before: This case is
           ;; straight and we just pick the correct one out of the
           ;; list:
           (setq result (nth (1- total-num) arg-list)))

          ;; Mandatory arg: Loop over the arg-list and drop all
          ;; vectors at the list beginning:
          ((eq type 'mandatory)
           (while (vectorp (car arg-list))
             (pop arg-list))
           ;; The next entry must be a mandatory arg.  If we're
           ;; looking for the first mandatory argument, just pick the
           ;; first element.  Otherwise loop further over the list and
           ;; count for the correct arg:
           (if (= mand-num 1)
               (setq result (car arg-list))
             (while again
               (cond ((vectorp (car arg-list))
                      (pop arg-list)
                      (setq again t))
                     ((= (cl-incf cnt) mand-num)
                      (setq again nil)
                      (setq result (car arg-list)))
                     (t
                      ;; Be a little conservative against infloops.
                      (if arg-list
                          (progn (setq again t)
                                 (pop arg-list))
                        (setq again nil)))))))

          ;; Optional arg after mandatory one(s): This isn't fun :-(
          ((and (eq type 'optional)
                (/= opt-dis 0))
           (setq again t)
           (setq cnt 0)
           ;; The idea is: Look for non-vectors and count the number
           ;; of mandatory argument in `mand-num'.
           (while again
             (cond ((and (not (vectorp (car arg-list)))
                         (/= (cl-incf cnt) mand-num))
                    (pop arg-list)
                    (setq again t))
                   ((and (not (vectorp (car arg-list)))
                         ;; Don't incf mand-num again; is done in the
                         ;; clause above:
                         (= cnt mand-num))
                    (setq again nil))
                   ;; If the clauses above fail, we can safely drop
                   ;; vectors:
                   ((vectorp (car arg-list))
                    (pop arg-list)
                    (setq again t))
                   (t
                    (setq again nil))))
           (setq result (nth opt-dis arg-list)))
          (t nil))
    result))

(defvar LaTeX-completion-function-map-alist-keyval nil
  "Alist mapping style funcs to completion-candidates counterparts.
Each element is a cons with the name of the function used in an
AUCTeX style file which queries and inserts something in the
buffer as car and a function delievering completion candidates as
cdr.  This list contains only mapping for functions which perform
key=val completions.  See also
`LaTeX-completion-function-map-alist-cr'.")

(defvar LaTeX-completion-function-map-alist-cr
  `((TeX-arg-counter . LaTeX-counter-list)
    (TeX-arg-pagestyle . LaTeX-pagestyle-list)
    (TeX-arg-environment . LaTeX-environment-list)
    (TeX-arg-length . ,(lambda () (mapcar (lambda (x)
                                            (concat TeX-esc (car x)))
                                          (LaTeX-length-list)))))
  "Alist mapping style funcs to completion-candidates counterparts.
Each element is a cons with the name of the function used in an
AUCTeX style file which queries and inserts something in the
buffer as car and a function delievering completion candidates as
cdr.  This list contains only mapping for functions which perform
completing-read.  See also
`LaTeX-completion-function-map-alist-keyval'.")

(defun LaTeX-completion-parse-arg (arg)
  "Parse ARG and call the correct candidates completion function.
ARG is the entry for the current argument in buffer stored in
`TeX-symbol-list' or `LaTeX-environment-list'."
  (when (or (and (vectorp arg)
                 (symbolp (elt arg 0))
                 (fboundp (elt arg 0)))
            (and (listp arg)
                 (symbolp (car arg))
                 (fboundp (car arg)))
            (and (symbolp arg)
                 (fboundp arg)))
    ;; Turn a vector into a list:
    (when (vectorp arg)
      (setq arg (append arg nil)))
    ;; Turn a single function symbol into a list:
    (unless (listp arg)
      (setq arg (list arg)))
    (let* ((head (car arg))
           (tail (cadr arg))
           (fun1 (lambda (elt)
                   (cond ((and (listp elt)
                               (symbolp (car elt))
                               (fboundp (car elt))
                               (not (eq (car elt) 'lambda)))
                          ;; It is a named function and not anonymous:
                          (funcall (car elt)))
                         ;; It is a function object
                         ((functionp elt)
                          (funcall elt))
                         ;; It is a variable name
                         ((and (symbolp elt)
                               (boundp elt))
                          (symbol-value elt))
                         ;; It is a plain list of strings:
                         (t elt)))))
      (cond ((eq head #'TeX-arg-key-val)
             (LaTeX-completion-candidates-key-val
              (funcall fun1 tail)))

            ((eq head #'TeX-arg-completing-read-multiple)
             (LaTeX-completion-candidates-completing-read-multiple
              (funcall fun1 tail)))

            ((eq head #'TeX-arg-completing-read)
             (LaTeX-completion-candidates-completing-read
              (funcall fun1 tail)))

            ((assq head LaTeX-completion-function-map-alist-keyval)
             (LaTeX-completion-candidates-key-val
              (funcall fun1 (cdr (assq head LaTeX-completion-function-map-alist-keyval)))))

            ((assq head LaTeX-completion-function-map-alist-cr)
             (LaTeX-completion-candidates-completing-read
              (funcall fun1 (cdr (assq head LaTeX-completion-function-map-alist-cr)))))

            (t nil)))))

(defun LaTeX-completion-find-argument-boundaries (&rest args)
  "Find the boundaries of the current LaTeX argument.
ARGS are characters passed to the function
`TeX-search-syntax-table'.  If ARGS are omitted, all characters
defined in the variable `LaTeX-completion-macro-delimiters' are
taken."
  (save-restriction
    (narrow-to-region (line-beginning-position -40)
                      (line-beginning-position  40))
    (let ((args (or args (LaTeX-completion-macro-delimiters)))
          (parse-sexp-ignore-comments (not (eq major-mode 'docTeX-mode))))
      (condition-case nil
          (with-syntax-table (apply #'TeX-search-syntax-table args)
            (scan-lists (point) 1 1))
        (error nil)))))

(defun LaTeX--arguments-completion-at-point ()
  "Capf for arguments of LaTeX macros and environments.
Completion for macros starting with `\\' is provided by the
function `TeX--completion-at-point' which should come first in
`completion-at-point-functions'."
  ;; Exit if not inside an argument or in a comment:
  (when (and (LaTeX-completion-find-argument-boundaries)
             (not (nth 4 (syntax-ppss))))
    (let ((entry (LaTeX-what-macro)))
      (cond ((and entry
                  (member (car entry) '("usepackage" "RequirePackage"
                                        "RequirePackageWithOptions"
                                        "documentclass" "LoadClass"
                                        "LoadClassWithOptions")))
             (LaTeX-completion-documentclass-usepackage entry))
            ((or (and entry
                      (eq (nth 1 entry) 'mac)
                      (assoc (car entry) (TeX-symbol-list)))
                 (and entry
                      (eq (nth 1 entry) 'env)
                      (assoc (car entry) (LaTeX-environment-list))))
             (LaTeX-completion-parse-arg
              (LaTeX-completion-parse-args entry)))
            ;; Any other constructs?
            (t nil)))))

;; The next defcustom and functions control the annotation of labels
;; during in-buffer completion which is done by
;; `TeX--completion-at-point' also inside the arguments of \ref and
;; such and not with the code above.

(defcustom LaTeX-label-annotation-max-length 30
  "Maximum number of characters for annotation of labels.
Setting this variable to 0 disables label annotation during
in-buffer completion."
  :group 'LaTeX-label
  :type 'integer)

(defun LaTeX-completion-label-annotation-function (label)
  "Return context for LABEL in a TeX file.
Context is a string gathered from RefTeX.  Return nil if
`LaTeX-label-annotation-max-length' is set to 0 or RefTeX-mode is
not activated.  Context is stripped to the number of characters
defined in `LaTeX-label-annotation-max-length'."
  (when (and (bound-and-true-p reftex-mode)
             (> LaTeX-label-annotation-max-length 0)
             (boundp 'reftex-docstruct-symbol))
    (let ((docstruct (symbol-value reftex-docstruct-symbol))
          s)
      (and (setq s (nth 2 (assoc label docstruct)))
           (concat " "
                   (string-trim-right
                    (substring s 0 (when (>= (length s)
                                             LaTeX-label-annotation-max-length)
                                     LaTeX-label-annotation-max-length))))))))

(defun LaTeX-completion-label-list ()
  "Return a list of defined labels for in-buffer completion.
This function checks if RefTeX mode is activated and extracts the
labels from there.  Otherwise the AUCTeX label list is returned.
If the list of offered labels is out of sync, re-parse the
document with `reftex-parse-all' or `TeX-normal-mode'."
  (if (and (bound-and-true-p reftex-mode)
           (fboundp 'reftex-access-scan-info)
           (boundp 'reftex-docstruct-symbol))
      (progn
        (reftex-access-scan-info)
        (let ((docstruct (symbol-value reftex-docstruct-symbol))
              labels)
          (dolist (label docstruct labels)
            (when (stringp (car label))
              (push (car label) labels)))))
    (LaTeX-label-list)))

;;; Mode

(defgroup LaTeX-macro nil
  "Special support for LaTeX macros in AUCTeX."
  :prefix "TeX-"
  :group 'LaTeX
  :group 'TeX-macro)

(defcustom TeX-arg-cite-note-p nil
  "If non-nil, ask for optional note in citations."
  :type 'boolean
  :group 'LaTeX-macro)

(defcustom TeX-arg-footnote-number-p nil
  "If non-nil, ask for optional number in footnotes."
  :type 'boolean
  :group 'LaTeX-macro)

(defcustom TeX-arg-item-label-p nil
  "If non-nil, always ask for optional label in items.
Otherwise, only ask in description environments."
  :type 'boolean
  :group 'LaTeX-macro)

(defcustom TeX-arg-right-insert-p t
  "If non-nil, always insert automatically the corresponding \\right.
This happens when \\left is inserted."
  :type 'boolean
  :group 'LaTeX-macro)

(defcustom LaTeX-mode-hook nil
  "A hook run in LaTeX mode buffers."
  :type 'hook
  :group 'LaTeX)

(TeX-abbrev-mode-setup LaTeX-mode latex-mode-abbrev-table)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.drv\\'" . LaTeX-mode) t) ;; append to the end of `auto-mode-alist' to give higher priority to Guix/Nix's derivation modes

;; HeVeA files (LaTeX -> HTML converter: http://hevea.inria.fr/)
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.hva\\'" . LaTeX-mode))

(defvar semantic-symref-filepattern-alist) ; Silence compiler
(with-eval-after-load 'semantic/symref/grep
  ;; This entry is necessary for M-? to work.
  ;; <URL:https://lists.gnu.org/r/auctex-devel/2023-09/msg00002.html>
  ;; <URL:https://lists.gnu.org/r/auctex-devel/2023-09/msg00005.html>
  (push '(LaTeX-mode "*.[tT]e[xX]" "*.ltx" "*.sty" "*.cl[so]" "*.bbl"
                     "*.drv" "*.hva")
        semantic-symref-filepattern-alist))

(declare-function LaTeX-preview-setup "preview")

;; Delete alias predefined in tex-mode.el so that AUCTeX autoload
;; takes precedence.
;;;###autoload (if (eq (symbol-function 'LaTeX-mode) 'latex-mode)
;;;###autoload     (defalias 'LaTeX-mode nil))
;;;###autoload
(define-derived-mode LaTeX-mode TeX-mode "LaTeX"
  "Major mode in AUCTeX for editing LaTeX files.
See info under AUCTeX for full documentation.

Entering LaTeX mode calls the value of `text-mode-hook',
then the value of `TeX-mode-hook', and then the value
of `LaTeX-mode-hook'."
  :after-hook (LaTeX-mode-cleanup)

  (LaTeX-common-initialization)
  (setq TeX-base-mode-name mode-name)
  (setq TeX-command-default "LaTeX")
  (setq TeX-sentinel-default-function #'TeX-LaTeX-sentinel)
  (add-hook 'tool-bar-mode-hook #'LaTeX-maybe-install-toolbar nil t)
  (LaTeX-maybe-install-toolbar)
  ;; Set the value of `LaTeX-using-Biber' based on the local value of
  ;; `LaTeX-biblatex-use-Biber'.  This should be run within
  ;; `TeX-update-style-hook' before toolbarx-refresh, otherwise the bibliography
  ;; button could be wrongly set.
  (add-hook 'TeX-update-style-hook
            (lambda ()
              (if (local-variable-p 'LaTeX-biblatex-use-Biber (current-buffer))
                  (setq LaTeX-using-Biber LaTeX-biblatex-use-Biber)))
            nil t)

  ;; Run style hooks associated with class options.
  (add-hook 'TeX-update-style-hook
            (lambda ()
              (let ((TeX-style-hook-dialect :classopt)
                    ;; Don't record class option names in
                    ;; `TeX-active-styles'.
                    (TeX-active-styles nil))
                (apply #'TeX-run-style-hooks
                       (apply #'append
                              (mapcar #'cdr LaTeX-provided-class-options)))))
            nil t)

  (when (fboundp 'LaTeX-preview-setup)
    (LaTeX-preview-setup))
  ;; Set up flymake backend, see latex-flymake.el
  (add-hook 'flymake-diagnostic-functions #'LaTeX-flymake nil t))

(defun LaTeX-mode-cleanup ()
  "Cleanup function for `LaTeX-mode'.
Run after mode hooks and file local variables application."
  ;; Defeat filladapt
  (if (bound-and-true-p filladapt-mode)
      (turn-off-filladapt-mode))

  ;; Keep `LaTeX-paragraph-commands-regexp' in sync with
  ;; `LaTeX-paragraph-commands' in case the latter is updated by
  ;; hooks or file (directory) local variables.
  (and (local-variable-p 'LaTeX-paragraph-commands)
       (setq-local LaTeX-paragraph-commands-regexp
                   (LaTeX-paragraph-commands-regexp-make)))
  ;; Don't do locally-bound test for `paragraph-start' because it
  ;; makes little sense; Style files casually call this function and
  ;; overwrite it unconditionally.  Users who need per-file
  ;; customization of `paragraph-start' should set
  ;; `LaTeX-paragraph-commands' instead.
  (LaTeX-set-paragraph-start)

  ;; Don't do locally-bound test for similar reason as above.  Users
  ;; who need per-file customization of
  ;; `LaTeX-indent-begin-regexp-local' etc. should set
  ;; `LaTeX-indent-begin-list' and so on instead.
  (LaTeX-indent-commands-regexp-make)

  (setq TeX-complete-list
        (append '(("\\\\cite\\[[^]\n\r\\%]*\\]{\\([^{}\n\r\\%,]*\\)"
                   1 LaTeX-bibitem-list "}")
                  ("\\\\cite{\\([^{}\n\r\\%,]*\\)" 1 LaTeX-bibitem-list "}")
                  ("\\\\cite{\\([^{}\n\r\\%]*,\\)\\([^{}\n\r\\%,]*\\)"
                   2 LaTeX-bibitem-list)
                  ("\\\\nocite{\\([^{}\n\r\\%,]*\\)" 1 LaTeX-bibitem-list "}")
                  ("\\\\nocite{\\([^{}\n\r\\%]*,\\)\\([^{}\n\r\\%,]*\\)"
                   2 LaTeX-bibitem-list)
                  ("\\\\[Rr]ef{\\([^{}\n\r\\%,]*\\)" 1 LaTeX-completion-label-list "}")
                  ("\\\\eqref{\\([^{}\n\r\\%,]*\\)" 1 LaTeX-completion-label-list "}")
                  ("\\\\pageref{\\([^{}\n\r\\%,]*\\)" 1 LaTeX-completion-label-list "}")
                  ("\\\\\\(index\\|glossary\\){\\([^{}\n\r\\%]*\\)"
                   2 LaTeX-index-entry-list "}")
                  ("\\\\begin{\\([A-Za-z]*\\)" 1 LaTeX-environment-list-filtered "}")
                  ("\\\\end{\\([A-Za-z]*\\)" 1 LaTeX-environment-list-filtered "}")
                  ("\\\\renewcommand\\*?{\\\\\\([A-Za-z]*\\)"
                   1 TeX-symbol-list-filtered "}")
                  ("\\\\renewenvironment\\*?{\\([A-Za-z]*\\)"
                   1 LaTeX-environment-list-filtered "}")
                  ("\\\\\\(this\\)?pagestyle{\\([A-Za-z]*\\)"
                   2 LaTeX-pagestyle-list "}")
                  (LaTeX--after-math-macro-prefix-p
                   1 (lambda ()
                       (seq-filter #'stringp
                                   (append (mapcar #'cadr LaTeX-math-list)
                                           (mapcar #'cadr LaTeX-math-default))))
                   (if TeX-insert-braces "{}")))
                TeX-complete-list)))

;; COMPATIBILITY for Emacs<29
;;;###autoload
(put 'LaTeX-mode 'auctex-function-definition (symbol-function 'LaTeX-mode))

;; Compatibility for former mode name.  Directory local variables
;; prepared for `latex-mode' continue to be valid for `LaTeX-mode'.
;; COMPATIBILITY for emacs<30: `tex-mode' can be removed from the list
;; once the least supported emacsen becomes 30.
(TeX-derived-mode-add-parents 'LaTeX-mode '(latex-mode tex-mode))

(with-eval-after-load 'semantic/symref/grep
  (push '(docTeX-mode "*.dtx") semantic-symref-filepattern-alist))

;; Enable LaTeX abbrevs in docTeX mode buffer.
;; No need to include text mode abbrev table as parents because LaTeX
;; mode abbrev table inherits it.
(let ((p (list LaTeX-mode-abbrev-table)))
  ;; Inherit abbrev table of the former name, if it exists.
  (if (boundp 'doctex-mode-abbrev-table)
      (push doctex-mode-abbrev-table p))
  (define-abbrev-table 'docTeX-mode-abbrev-table nil nil :parents p))

;;;###autoload
(define-derived-mode docTeX-mode LaTeX-mode "docTeX"
  "Major mode in AUCTeX for editing .dtx files derived from `LaTeX-mode'.
Runs `LaTeX-mode', sets a few variables and
runs the hooks in `docTeX-mode-hook'."
  (setq-local LaTeX-insert-into-comments t)
  (setq-local LaTeX-syntactic-comments t)
  (setq TeX-default-extension docTeX-default-extension)
  ;; Make filling and indentation aware of DocStrip guards.
  (setq paragraph-start (concat paragraph-start "\\|%<")
        paragraph-separate (concat paragraph-separate "\\|%<")
        TeX-comment-start-regexp "\\(?:%\\(?:<[^>]+>\\)?\\)")
  (setq TeX-base-mode-name mode-name)
  ;; We can remove the next `setq' when syntax propertization
  ;; decouples font lock and `font-latex-setup' stops calling
  ;; `font-lock-set-defaults'.
  (setq font-lock-set-defaults nil)
  (funcall TeX-install-font-lock))

;; Compatibility for former mode name.  Directory local variables
;; prepared for `doctex-mode' continue to be valid for `docTeX-mode'.
;; In addition, dir local vars for `latex-mode' are now valid for
;; `docTeX-mode' as well.
;; COMPATIBILITY for emacs<30: `latex-mode' and `tex-mode' can be removed
;; from the list once the least supported emacsen becomes 30.
(TeX-derived-mode-add-parents 'docTeX-mode '(doctex-mode latex-mode tex-mode))

(defcustom docTeX-clean-intermediate-suffixes
  TeX-clean-default-intermediate-suffixes
  "List of regexps matching suffixes of files to be deleted.
The regexps will be anchored at the end of the file name to be matched,
that is, you do _not_ have to cater for this yourself by adding \\\\\\=' or $."
  :type '(repeat regexp)
  :group 'TeX-command)

(defcustom docTeX-clean-output-suffixes TeX-clean-default-output-suffixes
  "List of regexps matching suffixes of files to be deleted.
The regexps will be anchored at the end of the file name to be matched,
that is, you do _not_ have to cater for this yourself by adding \\\\\\=' or $."
  :type '(repeat regexp)
  :group 'TeX-command)

(defcustom LaTeX-clean-intermediate-suffixes
  (append TeX-clean-default-intermediate-suffixes
          ;; These are extensions of files created by makeglossaries.
          '("\\.acn" "\\.acr" "\\.alg" "\\.glg" "\\.ist"))
  "List of regexps matching suffixes of files to be deleted.
The regexps will be anchored at the end of the file name to be matched,
that is, you do _not_ have to cater for this yourself by adding \\\\\\=' or $."
  :type '(repeat regexp)
  :group 'TeX-command)

(defcustom LaTeX-clean-output-suffixes TeX-clean-default-output-suffixes
  "List of regexps matching suffixes of files to be deleted.
The regexps will be anchored at the end of the file name to be matched,
that is, you do _not_ have to cater for this yourself by adding \\\\\\=' or $."
  :type '(repeat regexp)
  :group 'TeX-command)

(defun LaTeX--after-math-macro-prefix-p ()
  "Return non-nil if point is after a macro prefix in math mode.
Also sets `match-data' so that group 1 is the already typed
prefix.

For example, in $a + \\a| - 17$ with | denoting point, the
function would return non-nil and `(match-string 1)' would return
\"a\" afterwards."
  (and (texmathp)
       (TeX-looking-at-backward "\\\\\\([a-zA-Z]*\\)")))

(defun LaTeX-common-initialization ()
  "Common initialization for LaTeX derived modes."
  (setq-local indent-line-function #'LaTeX-indent-line)

  ;; Filling
  (setq-local paragraph-ignore-fill-prefix t)
  (setq-local fill-paragraph-function #'LaTeX-fill-paragraph)
  (setq-local adaptive-fill-mode nil)
  ;; Cater for \verb|...| (and similar) contructs which should not be
  ;; broken.
  (add-to-list (make-local-variable 'fill-nobreak-predicate)
               #'LaTeX-verbatim-p t)

  (or LaTeX-largest-level
      (setq LaTeX-largest-level (LaTeX-section-level "section")))

  (setq TeX-header-end LaTeX-header-end
        TeX-trailer-start LaTeX-trailer-start)
  (setq-local TeX-style-hook-dialect TeX-dialect)

  (require 'outline)
  (setq-local outline-level #'LaTeX-outline-level)
  (setq-local outline-regexp (LaTeX-outline-regexp t))
  (when (boundp 'outline-heading-alist)
    (setq outline-heading-alist
          (mapcar (lambda (x)
                    (cons (concat "\\" (nth 0 x)) (nth 1 x)))
                  LaTeX-section-list)))

  (setq-local TeX-auto-full-regexp-list
              (delete-dups (append LaTeX-auto-regexp-list
                                   ;; Prevent inadvertent destruction
                                   ;; of `plain-TeX-auto-regexp-list'.
                                   (copy-sequence
                                    plain-TeX-auto-regexp-list))))

  ;; Moved after `run-mode-hooks'. (bug#65750)
  ;; (LaTeX-set-paragraph-start)
  (setq paragraph-separate
        (concat
         "[ \t]*%*[ \t]*\\("
         "\\$\\$"                       ; Plain TeX display math
         "\\|$\\)"))

  (setq TeX-verbatim-p-function #'LaTeX-verbatim-p)
  (setq TeX-search-forward-comment-start-function
        #'LaTeX-search-forward-comment-start)
  (setq-local TeX-search-files-type-alist LaTeX-search-files-type-alist)

  (setq-local beginning-of-defun-function #'LaTeX-find-matching-begin)
  (setq-local end-of-defun-function       #'LaTeX-find-matching-end)

  ;; Moved after `run-mode-hooks'. (bug#65750)
  ;; (LaTeX-indent-commands-regexp-make)

  ;; Standard Emacs completion-at-point support.  We append the entry
  ;; in order to let `TeX--completion-at-point' be first in the list:
  (add-hook 'completion-at-point-functions
            #'LaTeX--arguments-completion-at-point 5 t)

  (setq-local LaTeX-item-list '(("description" . LaTeX-item-argument)
                                ("thebibliography" . LaTeX-item-bib)
                                ("array" . LaTeX-item-array)
                                ("tabular" . LaTeX-item-array)
                                ("tabular*" . LaTeX-item-tabular*)))

  (LaTeX-add-environments
   '("document" LaTeX-env-document)
   '("enumerate" LaTeX-env-item)
   '("itemize" LaTeX-env-item)
   '("list" LaTeX-env-list)
   '("trivlist" LaTeX-env-item)
   '("picture" LaTeX-env-picture)
   '("tabular" LaTeX-env-array)
   '("tabular*" LaTeX-env-tabular*)
   '("array" LaTeX-env-array)
   '("eqnarray" LaTeX-env-label)
   '("equation" LaTeX-env-label)
   '("minipage" LaTeX-env-minipage)

   ;; The following have no special support, but are included in
   ;; case the auto files are missing.

   "sloppypar" "tabbing" "verbatim" "verbatim*"
   "flushright" "flushleft" "displaymath" "math" "quote" "quotation"
   "center" "titlepage" "verse" "eqnarray*"

   ;; The following are not defined in latex.el, but in a number of
   ;; other style files.  I'm to lazy to copy them to all the
   ;; corresponding .el files right now.

   ;; This means that AUCTeX will complete e.g.
   ;; ``thebibliography'' in a letter, but I guess we can live with
   ;; that.

   '("description" LaTeX-env-item)
   '("figure" LaTeX-env-figure)
   '("figure*" LaTeX-env-figure)
   '("table" LaTeX-env-figure)
   '("table*" LaTeX-env-figure)
   '("thebibliography" LaTeX-env-bib)
   '("theindex" LaTeX-env-item))

  ;; `latex.ltx' defines `plain' and `empty' pagestyles
  (LaTeX-add-pagestyles "plain" "empty")

  ;; `latex.ltx' defines the following counters
  (LaTeX-add-counters "page" "equation" "enumi" "enumii" "enumiii"
                      "enumiv" "footnote" "mpfootnote")

  (LaTeX-add-lengths "arraycolsep" "arrayrulewidth" "baselineskip" "baselinestretch"
                     "bibindent" "columnsep" "columnseprule" "columnwidth"
                     "dblfloatsep" "dbltextfloatsep" "doublerulesep" "evensidemargin"
                     "fboxrule" "fboxsep" "floatsep" "footnotesep"
                     "headheight" "headsep"
                     "intextsep" "linewidth"
                     "marginparpush" "marginparsep" "marginparwidth"
                     "oddsidemargin" "paperwidth" "paperheight" "parindent" "parskip"
                     "stockheight" "stockwidth"
                     "tabcolsep" "textfloatsep" "textheight" "textwidth" "topmargin"
                     "unitlength")

  (TeX-add-symbols
   '("addtocounter" TeX-arg-counter "Value")
   '("alph" TeX-arg-counter)
   '("arabic" TeX-arg-counter)
   '("fnsymbol" TeX-arg-counter)
   '("newcounter" TeX-arg-define-counter
     [ TeX-arg-counter "Within counter" ])
   '("roman" TeX-arg-counter)
   '("setcounter" TeX-arg-counter "Value")
   '("usecounter" TeX-arg-counter)
   '("value" TeX-arg-counter)
   '("stepcounter" TeX-arg-counter)
   '("refstepcounter" TeX-arg-counter)
   '("label" TeX-arg-define-label)
   '("pageref" TeX-arg-ref)
   '("ref" TeX-arg-ref)
   ;; \Ref and \labelformat are part of kernel with LaTeX 2019-10-01:
   '("Ref" TeX-arg-ref)
   '("labelformat" TeX-arg-counter t)
   ;; \footref is part of kernel with LaTeX 2021-06-01:
   '("footref" TeX-arg-ref)
   '("newcommand" TeX-arg-define-macro [ TeX-arg-define-macro-arguments ] t)
   '("renewcommand" TeX-arg-macro [ TeX-arg-define-macro-arguments ] t)
   '("newenvironment" TeX-arg-define-environment
     [ TeX-arg-define-macro-arguments ] 2)
   '("renewenvironment" TeX-arg-environment
     [ TeX-arg-define-macro-arguments ] 2)
   '("providecommand" TeX-arg-define-macro [ TeX-arg-define-macro-arguments ] t)
   '("providecommand*" TeX-arg-define-macro [ TeX-arg-define-macro-arguments ] t)
   '("newcommand*" TeX-arg-define-macro [ TeX-arg-define-macro-arguments ] t)
   '("renewcommand*" TeX-arg-macro [ TeX-arg-define-macro-arguments ] t)
   '("newenvironment*" TeX-arg-define-environment
     [ TeX-arg-define-macro-arguments ] 2)
   '("renewenvironment*" TeX-arg-environment
     [ TeX-arg-define-macro-arguments ] 2)
   ;; \newtheorem comes in 3 flavors:
   ;; \newtheorem{name}{title} or
   ;; \newtheorem{name}[numbered_like]{title} or
   ;; \newtheorem{name}{title}[numbered_within]
   ;; Both optional args are not allowed
   '("newtheorem" TeX-arg-define-environment
     [ TeX-arg-environment "Numbered like" ]
     "Title"
     (TeX-arg-conditional (save-excursion
                            (skip-chars-backward (concat "^" TeX-grcl))
                            (backward-list)
                            (= (preceding-char) ?\]))
         ()
       ([TeX-arg-counter "Within counter"])))
   '("newfont" TeX-arg-define-macro t)
   '("circle" "Diameter")
   '("circle*" "Diameter")
   '("dashbox" "Dash Length" TeX-arg-size
     [ TeX-arg-corner ] t)
   '("frame" t)
   '("framebox" (TeX-arg-conditional
                    (string-equal (LaTeX-current-environment) "picture")
                    (TeX-arg-size [ TeX-arg-corner ] t)
                  ([ "Length" ] [ TeX-arg-lr ] t)))
   '("line" (TeX-arg-pair "X slope" "Y slope") "Length")
   '("linethickness" "Dimension")
   '("makebox" (TeX-arg-conditional
                   (string-equal (LaTeX-current-environment) "picture")
                   (TeX-arg-size [ TeX-arg-corner ] t)
                 ([ "Length" ] [ TeX-arg-lr ] t)))
   '("multiput"
     TeX-arg-coordinate
     (TeX-arg-pair "X delta" "Y delta")
     "Number of copies"
     t)
   '("oval" TeX-arg-size [ TeX-arg-corner "Portion" ])
   '("put" TeX-arg-coordinate t)
   '("savebox" TeX-arg-savebox
     (TeX-arg-conditional
         (string-equal (LaTeX-current-environment) "picture")
         (TeX-arg-size [ TeX-arg-corner ] t)
       ([ "Length" ] [ TeX-arg-lr ] t)))
   '("shortstack" [ TeX-arg-lr ] t)
   '("vector" (TeX-arg-pair "X slope" "Y slope") "Length")
   '("cline" "Span `i-j'")
   '("multicolumn" "Columns" "Format" t)
   '("item"
     (TeX-arg-conditional (or TeX-arg-item-label-p
                              (string-equal (LaTeX-current-environment)
                                            "description"))
         ([ "Item label" ])
       ())
     (TeX-arg-literal " "))
   '("bibitem" [ "Bibitem label" ] TeX-arg-define-cite)
   '("cite"
     (TeX-arg-conditional TeX-arg-cite-note-p ([ "Note" ]) ())
     TeX-arg-cite)
   '("nocite" TeX-arg-cite)
   '("bibliographystyle" TeX-arg-bibstyle)
   '("bibliography" TeX-arg-bibliography)
   '("newblock" (TeX-arg-literal " "))
   '("footnote"
     (TeX-arg-conditional TeX-arg-footnote-number-p ([ "Number" ]) nil)
     t)
   '("footnotetext"
     (TeX-arg-conditional TeX-arg-footnote-number-p ([ "Number" ]) nil)
     t)
   '("footnotemark"
     (TeX-arg-conditional TeX-arg-footnote-number-p ([ "Number" ]) nil))
   '("newlength" (TeX-arg-define-length "Length macro"))
   '("setlength" (TeX-arg-length "Length macro" nil "\\")
     (TeX-arg-length "Length value"))
   '("addtolength" (TeX-arg-length "Length macro" nil "\\")
     (TeX-arg-length "Length to add"))
   '("settowidth" (TeX-arg-length "Length macro" nil "\\") "Text")
   '("settoheight" (TeX-arg-length "Length macro" nil "\\") "Text")
   '("settodepth" (TeX-arg-length "Length macro" nil "\\") "Text")
   '("\\" [ "Space" ])
   '("\\*" [ "Space" ])
   '("hyphenation" t)
   '("linebreak" [ "How much [0 - 4]" ])
   '("nolinebreak" [ "How much [0 - 4]" ])
   '("nopagebreak" [ "How much [0 - 4]" ])
   '("pagebreak" [ "How much [0 - 4]" ])
   '("stackrel" t nil)
   '("frac" t nil)
   '("lefteqn" t)
   '("overbrace" t)
   '("overline" t)
   '("overleftarrow" t)
   '("overrightarrow" t)
   '("sqrt" [ "Root" ] t)
   '("underbrace" t)
   '("underline" t)
   '("acute" t) '("grave" t) '("ddot" t) '("tilde" t) '("bar" t)
   '("breve" t) '("check" t) '("hat" t) '("vec" t) '("dot" t)
   '("widetilde" t) '("widehat" t)
   '("author" LaTeX-arg-author)
   '("date" TeX-arg-date)
   '("thanks" t)
   '("title" t)
   '("pagenumbering" (TeX-arg-completing-read
                      ("arabic" "roman" "Roman" "alph" "Alph")
                      "Numbering style"))
   '("pagestyle" TeX-arg-pagestyle)
   '("markboth" t nil)
   '("markright" t)
   '("thispagestyle" TeX-arg-pagestyle)
   '("addvspace" TeX-arg-length)
   '("fbox" t)
   '("hspace*" TeX-arg-length)
   '("hspace" TeX-arg-length)
   '("mbox" t)
   '("newsavebox" TeX-arg-define-savebox)
   '("parbox"
     [TeX-arg-tb nil center]
     [TeX-arg-length "Height"]
     [TeX-arg-tb "Inner position" stretch]
     (TeX-arg-length "Width")
     t)
   '("raisebox" "Raise" [ "Height above" ] [ "Depth below" ] t)
   '("rule" [ "Raise" ] "Width" "Thickness")
   '("sbox" TeX-arg-savebox t)
   '("usebox" TeX-arg-savebox)
   '("vspace*" TeX-arg-length)
   '("vspace" TeX-arg-length)
   '("documentstyle" TeX-arg-document)
   '("include" (TeX-arg-input-file "File" t))
   '("includeonly" t)
   '("input" TeX-arg-input-file)
   '("addcontentsline"
     (TeX-arg-completing-read ("toc" "lof" "lot") "File")
     (TeX-arg-completing-read LaTeX-section-list "Numbering style") t)
   '("addtocontents"
     (TeX-arg-completing-read ("toc" "lof" "lot") "File") t)
   '("typeout" t)
   '("typein" [ TeX-arg-define-macro ] t)
   '("verb" TeX-arg-verb)
   '("verb*" TeX-arg-verb)
   '("extracolsep" t)
   '("index" TeX-arg-index)
   '("glossary" TeX-arg-index)
   '("numberline" "Section number" "Heading")
   '("caption" t)
   '("marginpar" [ "Left margin text" ] "Text")
   '("left" TeX-arg-insert-braces)
   ;; The following 4 macros are not specific to amsmath.
   '("bigl" TeX-arg-insert-braces)
   '("Bigl" TeX-arg-insert-braces)
   '("biggl" TeX-arg-insert-braces)
   '("Biggl" TeX-arg-insert-braces)

   '("langle" TeX-arg-insert-right-brace-maybe)
   '("lceil" TeX-arg-insert-right-brace-maybe)
   '("lfloor" TeX-arg-insert-right-brace-maybe)

   ;; These have no special support, but are included in case the
   ;; auto files are missing.

   "TeX" "LaTeX"
   "samepage" "newline"
   "smallskip" "medskip" "bigskip" "fill" "stretch"
   "thinspace" "negthinspace" "enspace" "enskip" "quad" "qquad"
   "nonumber" "centering" "raggedright"
   "raggedleft" "kill" "pushtabs" "poptabs" "protect" "arraystretch"
   "hline" "vline" "cline" "thinlines" "thicklines" "and" "makeindex"
   "makeglossary" "reversemarginpar" "normalmarginpar"
   "raggedbottom" "flushbottom" "sloppy" "fussy" "newpage"
   "clearpage" "cleardoublepage" "twocolumn" "onecolumn"

   "maketitle" "tableofcontents" "listoffigures" "listoftables"
   '("tiny" -1) '("scriptsize" -1) '("footnotesize" -1) '("small" -1)
   '("normalsize" -1) '("large" -1) '("Large" -1) '("LARGE" -1) '("huge" -1)
   '("Huge" -1)
   '("oldstylenums" "Numbers")
   ;; The next macro is provided by LaTeX2e 2020-02-02 release:
   '("legacyoldstylenums" "Numbers")
   "pounds" "copyright"
   "hfil" "hfill" "vfil" "vfill" "hrulefill" "dotfill"
   "indent" "noindent" "today"
   "appendix"
   "dots"
   "makeatletter" "makeatother" "jobname")

  (when (string-equal LaTeX-version "2e")
    (LaTeX-add-environments
     '("filecontents" LaTeX-env-args
       [TeX-arg-completing-read-multiple
        ("overwrite" "force" "nosearch" "nowarn" "noheader")]
       "File")
     '("filecontents*" LaTeX-env-args
       [TeX-arg-completing-read-multiple
        ("overwrite" "force" "nosearch" "nowarn")]
       "File"))

    (TeX-add-symbols
     '("enlargethispage"  (TeX-arg-length nil "1.0\\baselineskip"))
     '("enlargethispage*" (TeX-arg-length nil "1.0\\baselineskip"))
     '("tabularnewline" [ TeX-arg-length ])
     '("suppressfloats" [ TeX-arg-tb "Suppress floats position" ])
     '("ensuremath" "Math commands")
     '("textsuperscript" "Text")
     '("textsubscript" "Text")
     '("textcircled" "Text")
     '("mathring" t)
     '("chaptermark" "Text")
     '("sectionmark" "Text")
     '("subsectionmark" "Text")
     '("subsubsectionmark" "Text")
     '("paragraphmark" "Text")
     '("subparagraphmark" "Text")

     "LaTeXe"
     "frontmatter" "mainmatter" "backmatter"
     "leftmark" "rightmark"
     "textcompwordmark" "textvisiblespace" "textemdash" "textendash"
     "textexclamdown" "textquestiondown" "textquotedblleft"
     "textquotedblright" "textquoteleft" "textquoteright"
     "textbackslash" "textbar" "textless" "textgreater"
     "textasciicircum" "textasciitilde"

     ;; With the advent of LaTeX2e release 2020-02-02, all symbols
     ;; provided by textcomp.sty are available out of the box by the
     ;; kernel.  The next block is moved here from textcomp.el:
     "capitalgrave"                 ; Type: Accent -- Slot: 0
     "capitalacute"                 ; Type: Accent -- Slot: 1
     "capitalcircumflex"            ; Type: Accent -- Slot: 2
     "capitaltilde"                 ; Type: Accent -- Slot: 3
     "capitaldieresis"              ; Type: Accent -- Slot: 4
     "capitalhungarumlaut"          ; Type: Accent -- Slot: 5
     "capitalring"                  ; Type: Accent -- Slot: 6
     "capitalcaron"                 ; Type: Accent -- Slot: 7
     "capitalbreve"                 ; Type: Accent -- Slot: 8
     "capitalmacron"                ; Type: Accent -- Slot: 9
     "capitaldotaccent"             ; Type: Accent -- Slot: 10
     "textquotestraightbase"        ; Type: Symbol -- Slot: 13
     "textquotestraightdblbase"     ; Type: Symbol -- Slot: 18
     "texttwelveudash"              ; Type: Symbol -- Slot: 21
     "textthreequartersemdash"      ; Type: Symbol -- Slot: 22
     "textcapitalcompwordmark"      ; Type: Symbol -- Slot: 23
     "textleftarrow"                ; Type: Symbol -- Slot: 24
     "textrightarrow"               ; Type: Symbol -- Slot: 25
     "t"                            ; Type: Accent -- Slot: 26
     "capitaltie"                   ; Type: Accent -- Slot: 27
     "newtie"                       ; Type: Accent -- Slot: 28
     "capitalnewtie"                ; Type: Accent -- Slot: 29
     "textascendercompwordmark"     ; Type: Symbol -- Slot: 31
     "textblank"                    ; Type: Symbol -- Slot: 32
     "textdollar"                   ; Type: Symbol -- Slot: 36
     "textquotesingle"              ; Type: Symbol -- Slot: 39
     "textasteriskcentered"         ; Type: Symbol -- Slot: 42
     "textdblhyphen"                ; Type: Symbol -- Slot: 45
     "textfractionsolidus"          ; Type: Symbol -- Slot: 47
     "textzerooldstyle"             ; Type: Symbol -- Slot: 48
     "textoneoldstyle"              ; Type: Symbol -- Slot: 49
     "texttwooldstyle"              ; Type: Symbol -- Slot: 50
     "textthreeoldstyle"            ; Type: Symbol -- Slot: 51
     "textfouroldstyle"             ; Type: Symbol -- Slot: 52
     "textfiveoldstyle"             ; Type: Symbol -- Slot: 53
     "textsixoldstyle"              ; Type: Symbol -- Slot: 54
     "textsevenoldstyle"            ; Type: Symbol -- Slot: 55
     "texteightoldstyle"            ; Type: Symbol -- Slot: 56
     "textnineoldstyle"             ; Type: Symbol -- Slot: 57
     "textlangle"                   ; Type: Symbol -- Slot: 60
     "textminus"                    ; Type: Symbol -- Slot: 61
     "textrangle"                   ; Type: Symbol -- Slot: 62
     "textmho"                      ; Type: Symbol -- Slot: 77
     "textbigcircle"                ; Type: Symbol -- Slot: 79
     "textohm"                      ; Type: Symbol -- Slot: 87
     "textlbrackdbl"                ; Type: Symbol -- Slot: 91
     "textrbrackdbl"                ; Type: Symbol -- Slot: 93
     "textuparrow"                  ; Type: Symbol -- Slot: 94
     "textdownarrow"                ; Type: Symbol -- Slot: 95
     "textasciigrave"               ; Type: Symbol -- Slot: 96
     "textborn"                     ; Type: Symbol -- Slot: 98
     "textdivorced"                 ; Type: Symbol -- Slot: 99
     "textdied"                     ; Type: Symbol -- Slot: 100
     "textleaf"                     ; Type: Symbol -- Slot: 108
     "textmarried"                  ; Type: Symbol -- Slot: 109
     "textmusicalnote"              ; Type: Symbol -- Slot: 110
     "texttildelow"                 ; Type: Symbol -- Slot: 126
     "textdblhyphenchar"            ; Type: Symbol -- Slot: 127
     "textasciibreve"               ; Type: Symbol -- Slot: 128
     "textasciicaron"               ; Type: Symbol -- Slot: 129
     "textacutedbl"                 ; Type: Symbol -- Slot: 130
     "textgravedbl"                 ; Type: Symbol -- Slot: 131
     "textdagger"                   ; Type: Symbol -- Slot: 132
     "textdaggerdbl"                ; Type: Symbol -- Slot: 133
     "textbardbl"                   ; Type: Symbol -- Slot: 134
     "textperthousand"              ; Type: Symbol -- Slot: 135
     "textbullet"                   ; Type: Symbol -- Slot: 136
     "textcelsius"                  ; Type: Symbol -- Slot: 137
     "textdollaroldstyle"           ; Type: Symbol -- Slot: 138
     "textcentoldstyle"             ; Type: Symbol -- Slot: 139
     "textflorin"                   ; Type: Symbol -- Slot: 140
     "textcolonmonetary"            ; Type: Symbol -- Slot: 141
     "textwon"                      ; Type: Symbol -- Slot: 142
     "textnaira"                    ; Type: Symbol -- Slot: 143
     "textguarani"                  ; Type: Symbol -- Slot: 144
     "textpeso"                     ; Type: Symbol -- Slot: 145
     "textlira"                     ; Type: Symbol -- Slot: 146
     "textrecipe"                   ; Type: Symbol -- Slot: 147
     "textinterrobang"              ; Type: Symbol -- Slot: 148
     "textinterrobangdown"          ; Type: Symbol -- Slot: 149
     "textdong"                     ; Type: Symbol -- Slot: 150
     "texttrademark"                ; Type: Symbol -- Slot: 151
     "textpertenthousand"           ; Type: Symbol -- Slot: 152
     "textpilcrow"                  ; Type: Symbol -- Slot: 153
     "textbaht"                     ; Type: Symbol -- Slot: 154
     "textnumero"                   ; Type: Symbol -- Slot: 155
     "textdiscount"                 ; Type: Symbol -- Slot: 156
     "textestimated"                ; Type: Symbol -- Slot: 157
     "textopenbullet"               ; Type: Symbol -- Slot: 158
     "textservicemark"              ; Type: Symbol -- Slot: 159
     "textlquill"                   ; Type: Symbol -- Slot: 160
     "textrquill"                   ; Type: Symbol -- Slot: 161
     "textcent"                     ; Type: Symbol -- Slot: 162
     "textsterling"                 ; Type: Symbol -- Slot: 163
     "textcurrency"                 ; Type: Symbol -- Slot: 164
     "textyen"                      ; Type: Symbol -- Slot: 165
     "textbrokenbar"                ; Type: Symbol -- Slot: 166
     "textsection"                  ; Type: Symbol -- Slot: 167
     "textasciidieresis"            ; Type: Symbol -- Slot: 168
     "textcopyright"                ; Type: Symbol -- Slot: 169
     "textordfeminine"              ; Type: Symbol -- Slot: 170
     "textcopyleft"                 ; Type: Symbol -- Slot: 171
     "textlnot"                     ; Type: Symbol -- Slot: 172
     "textcircledP"                 ; Type: Symbol -- Slot: 173
     "textregistered"               ; Type: Symbol -- Slot: 174
     "textasciimacron"              ; Type: Symbol -- Slot: 175
     "textdegree"                   ; Type: Symbol -- Slot: 176
     "textpm"                       ; Type: Symbol -- Slot: 177
     "texttwosuperior"              ; Type: Symbol -- Slot: 178
     "textthreesuperior"            ; Type: Symbol -- Slot: 179
     "textasciiacute"               ; Type: Symbol -- Slot: 180
     "textmu"                       ; Type: Symbol -- Slot: 181
     "textparagraph"                ; Type: Symbol -- Slot: 182
     "textperiodcentered"           ; Type: Symbol -- Slot: 183
     "textreferencemark"            ; Type: Symbol -- Slot: 184
     "textonesuperior"              ; Type: Symbol -- Slot: 185
     "textordmasculine"             ; Type: Symbol -- Slot: 186
     "textsurd"                     ; Type: Symbol -- Slot: 187
     "textonequarter"               ; Type: Symbol -- Slot: 188
     "textonehalf"                  ; Type: Symbol -- Slot: 189
     "textthreequarters"            ; Type: Symbol -- Slot: 190
     "texteuro"                     ; Type: Symbol -- Slot: 191
     "texttimes"                    ; Type: Symbol -- Slot: 214
     "textdiv"                      ; Type: Symbol -- Slot: 246
     '("capitalcedilla"       1)    ; Type: Command -- Slot: N/A
     '("capitalogonek"        1)    ; Type: Command -- Slot: N/A

     "rmfamily" "sffamily" "ttfamily"
     '("mdseries" -1) '("bfseries" -1)
     '("itshape"  -1) '("slshape"  -1)
     '("upshape"  -1) '("scshape"  -1)
     '("eminnershape" -1)
     ;; The next 3 were added to LaTeX kernel with 2020-02-02 release:
     '("sscshape" -1) '("swshape"  -1) '("ulcshape" -1)
     ;; These are for the default settings:
     "encodingdefault" "familydefault" "seriesdefault" "shapedefault"
     "rmdefault" "sfdefault" "ttdefault"
     "bfdefault" "mddefault"
     "itdefault" "sldefault" "scdefault" "updefault"
     "sscdefault" "swdefault" "ulcdefault"
     ;; This macro is for `spaced small caps'.  Currently, only some
     ;; commercial fonts offer this.  It should be moved into
     ;; `LaTeX-font-list' once it is needed more frequently.
     '("textssc" t)
     ;; User level reset macros:
     '("normalfont" -1) '("normalshape" -1)

     ;; Low level commands for selecting a font:
     '("fontencoding" "Encoding")
     '("fontfamily" "Family")
     '("fontseries" "Series")
     '("fontseriesforce" "Series")
     '("fontshape" "Shape")
     '("fontshapeforce" "Shape")
     '("fontsize" "Size" "Baselineskip")
     "selectfont"
     '("usefont" "Encoding" "Family" "Series" "Shape")
     '("linespread" "Factor")

     ;; This one only be used outside math mode:
     '("mathversion" (TeX-arg-completing-read ("normal" "bold") "Version"))

     ;; Macros for document-command parser, aka xparse added to LaTeX
     ;; kernel with 2020-10-01 release and documented in usrguide.pdf
     '("NewDocumentCommand"
       TeX-arg-define-macro "Argument specification" t)
     '("RenewDocumentCommand"
       TeX-arg-macro "Argument specification" t)
     '("ProvideDocumentCommand"
       TeX-arg-define-macro "Argument specification" t)
     '("DeclareDocumentCommand"
       TeX-arg-define-macro "Argument specification" t)

     ;; Declaring environments
     '("NewDocumentEnvironment" TeX-arg-define-environment
       "Argument specification" t t)
     '("RenewDocumentEnvironment" TeX-arg-environment
       "Argument specification" t t)
     '("ProvideDocumentEnvironment" TeX-arg-define-environment
       "Argument specification" t t)
     '("DeclareDocumentEnvironment" TeX-arg-define-environment
       "Argument specification" t t)

     ;; Fully-expandable document commands
     '("DeclareExpandableDocumentCommand"
       TeX-arg-define-macro "Argument specification" t)
     '("NewExpandableDocumentCommand"
       TeX-arg-define-macro "Argument specification" t)
     '("RenewExpandableDocumentCommand"
       TeX-arg-macro "Argument specification" t)
     '("ProvideExpandableDocumentCommand"
       TeX-arg-define-macro "Argument specification" t)

     ;; Testing special values
     '("IfNoValueTF" 3)
     '("IfNoValueT" 2)
     '("IfNoValueF" 2)
     '("IfValueTF" 3)
     '("IfValueT" 2)
     '("IfValueF" 2)
     '("IfBlankTF" 3)
     '("IfBlankT" 2)
     '("IfBlankF" 2)
     "BooleanTrue"
     "BooleanFalse"
     '("IfBooleanTF" 3)
     '("IfBooleanT" 2)
     '("IfBooleanF" 2)

     ;; Argument processors
     '("SplitArgument" "Number" "Token")
     '("SplitList" "Token")
     '("ProcessList" "List" "Function")
     "ReverseBoolean"
     "TrimSpaces"
     "ProcessedArgument"

     ;; Copying and showing (robust) commands and environments
     '("NewCommandCopy" TeX-arg-define-macro TeX-arg-macro)
     '("RenewCommandCopy" TeX-arg-define-macro TeX-arg-macro)
     '("DeclareCommandCopy" TeX-arg-define-macro TeX-arg-macro)
     '("ShowCommand"        TeX-arg-macro)

     '("NewEnvironmentCopy" TeX-arg-define-environment TeX-arg-environment)
     '("RenewEnvironmentCopy" TeX-arg-define-environment TeX-arg-environment)
     '("DeclareEnvironmentCopy" TeX-arg-define-environment TeX-arg-environment)
     '("ShowEnvironment" TeX-arg-environment)

     ;; Preconstructing command names (or otherwise expanding arguments)
     '("UseName" "String")
     ;; Only offer the predictable part
     '("ExpandArgs"
       (TeX-arg-completing-read ("c" "cc" "Nc") "Spec"))

     ;; Expandable floating point (and other) calculations
     '("fpeval" t)
     '("inteval" t)
     '("dimeval" t)
     '("skipeval" t)

     ;; Case changing
     '("MakeUppercase" [TeX-arg-key-val (("lang") ("locale"))] t)
     '("MakeLowercase" [TeX-arg-key-val (("lang") ("locale"))] t)
     '("MakeTitlecase" [TeX-arg-key-val (("lang") ("locale")
                                         ("words" ("first" "all")))]
       t)

     ;; Support for problem solving
     '("listfiles"
       [TeX-arg-completing-read-multiple ("hashes" "sizes")])

     ;; LaTeX hook macros:
     '("AddToHook"      TeX-arg-hook [ "Label" ] t)
     '("RemoveFromHook" TeX-arg-hook [ "Label" ])
     '("AddToHookNext"  TeX-arg-hook t)

     ;; Added in LaTeX 2021-11-15
     '("counterwithin"
       [TeX-arg-completing-read ("\\arabic" "\\roman" "\\Roman"
                                 "\\alph" "\\Alph")
                                "Format"]
       (TeX-arg-counter)
       (TeX-arg-counter "Within counter"))
     '("counterwithin*"
       [TeX-arg-completing-read ("\\arabic" "\\roman" "\\Roman"
                                 "\\alph" "\\Alph")
                                "Format"]
       (TeX-arg-counter)
       (TeX-arg-counter "Within counter"))

     '("counterwithout"
       [TeX-arg-completing-read ("\\arabic" "\\roman" "\\Roman"
                                 "\\alph" "\\Alph")
                                "Format"]
       (TeX-arg-counter)
       (TeX-arg-counter "Within counter"))
     '("counterwithout*"
       [TeX-arg-completing-read ("\\arabic" "\\roman" "\\Roman"
                                 "\\alph" "\\Alph")
                                "Format"]
       (TeX-arg-counter)
       (TeX-arg-counter "Within counter"))

     ;; Added in LaTeX 2022-06-01
     '("NewMarkClass" "Class")
     '("InsertMark" "Class" t)
     '("TopMark"
       [TeX-arg-completing-read ("page"         "previous-page"
                                 "column"       "previous-column"
                                 "first-column" "last-column")
                                "Region"]
       (TeX-arg-completing-read ("2e-left" "2e-right" "2e-right-nonempty")
                                "Class"))
     '("FirstMark"
       [TeX-arg-completing-read ("page"         "previous-page"
                                 "column"       "previous-column"
                                 "first-column" "last-column")
                                "Region"]
       (TeX-arg-completing-read ("2e-left" "2e-right" "2e-right-nonempty")
                                "Class"))
     '("LastMark"
       [TeX-arg-completing-read ("page"         "previous-page"
                                 "column"       "previous-column"
                                 "first-column" "last-column")
                                "Region"]
       (TeX-arg-completing-read ("2e-left" "2e-right" "2e-right-nonempty")
                                "Class"))
     '("IfMarksEqualTF"
       [TeX-arg-completing-read ("page"         "previous-page"
                                 "column"       "previous-column"
                                 "first-column" "last-column")
                                "Region"]
       (TeX-arg-completing-read ("2e-left" "2e-right" "2e-right-nonempty")
                                "Class")
       (TeX-arg-completing-read ("top" "first" "last")
                                "Position 1")
       (TeX-arg-completing-read ("top" "first" "last")
                                "Position 2")
       2)

     '("DocumentMetadata"
       (TeX-arg-key-val (("backend")
                         ("pdfversion")
                         ("uncompress")
                         ("lang")
                         ("pdfstandard" ("A-1b" "A-2a" "A-2b" "A-2u" "A-3a"
                                         "A-3b" "A-3u" "A-4" "A-4E" "A-4F"
                                         "X-4" "X-4p" "X-5g" "X-5n" "X-5pg"
                                         "X-6" "X-6n" "X-6p" "UA-1" "UA-2"))
                         ("xmp" ("true" "false"))
                         ("colorprofiles")
                         ;; Skip the individual modules:
                         ("testphase" ("phase-I" "phase-II" "phase-III"))
                         ("debug" ("para" "log" "uncompress" "pdfmanagement"
                                   "firstaidoff" "xmp-export" "tagpdf"))))) ))

  (TeX-run-style-hooks "LATEX")

  (make-local-variable 'TeX-font-list)
  (make-local-variable 'TeX-font-replace-function)
  (if (string-equal LaTeX-version "2")
      ()
    (setq TeX-font-list LaTeX-font-list)
    (setq TeX-font-replace-function #'TeX-font-replace-macro)
    (TeX-add-symbols
     '("usepackage" LaTeX-arg-usepackage)
     '("RequirePackage" LaTeX-arg-usepackage)
     '("ProvidesPackage" (TeX-arg-file-name-sans-extension "Package name")
       [ TeX-arg-conditional (y-or-n-p "Insert version? ")
           ([ TeX-arg-version ]) nil])
     '("ProvidesClass" (TeX-arg-file-name-sans-extension "Class name")
       [ TeX-arg-conditional (y-or-n-p "Insert version? ")
           ([ TeX-arg-version ]) nil])
     '("ProvidesFile" (TeX-arg-file-name "File name")
       [ TeX-arg-conditional (y-or-n-p "Insert version? ")
           ([ TeX-arg-version ]) nil ])
     '("documentclass" TeX-arg-document)))

  (TeX-add-style-hook "latex2e"
                      ;; Use new fonts for `\documentclass' documents.
                      (lambda ()
                        (setq TeX-font-list LaTeX-font-list)
                        (setq TeX-font-replace-function #'TeX-font-replace-macro)
                        (run-hooks 'LaTeX2e-hook))
                      TeX-dialect)

  (TeX-add-style-hook "latex2"
                      ;; Use old fonts for `\documentstyle' documents.
                      (lambda ()
                        (setq TeX-font-list (default-value 'TeX-font-list))
                        (setq TeX-font-replace-function
                              (default-value 'TeX-font-replace-function))
                        (run-hooks 'LaTeX2-hook))
                      TeX-dialect)

  ;; There must be something better-suited, but I don't understand the
  ;; parsing properly.  -- dak
  (TeX-add-style-hook "pdftex" #'TeX-PDF-mode-on :classopt)
  (TeX-add-style-hook "pdftricks" #'TeX-PDF-mode-on :classopt)
  (TeX-add-style-hook "pst-pdf" #'TeX-PDF-mode-on :classopt)
  (TeX-add-style-hook "dvips"
                      (lambda ()
                        ;; Leave at user's choice whether to disable
                        ;; `TeX-PDF-mode' or not.
                        (setq TeX-PDF-from-DVI "Dvips"))
                      :classopt)
  ;; This is now done in style/pstricks.el because it prevents other
  ;; pstricks style files from being loaded.
  ;;   (TeX-add-style-hook "pstricks" 'TeX-PDF-mode-off)
  (TeX-add-style-hook "psfrag" #'TeX-PDF-mode-off :classopt)
  (TeX-add-style-hook "dvipdf" #'TeX-PDF-mode-off :classopt)
  (TeX-add-style-hook "dvipdfm" #'TeX-PDF-mode-off :classopt)
  (TeX-add-style-hook "dvipdfmx"
                      (lambda ()
                        (TeX-PDF-mode-on)
                        ;; XeLaTeX normally don't use dvipdfmx
                        ;; explicitly.
                        (unless (eq TeX-engine 'xetex)
                          (setq TeX-PDF-from-DVI "Dvipdfmx")))
                      :classopt)
  ;;  (TeX-add-style-hook "DVIoutput" 'TeX-PDF-mode-off)
  ;;
  ;;  Well, DVIoutput indicates that we want to run PDFTeX and expect to
  ;;  get DVI output.  Ugh.
  (TeX-add-style-hook "ifpdf" (lambda ()
                                (TeX-PDF-mode-on)
                                (TeX-PDF-mode-off))
                      :classopt)
  ;; ifpdf indicates that we cater for either.  So calling both
  ;; functions will make sure that the default will get used unless the
  ;; user overrode it.

  (setq-local imenu-create-index-function
              #'LaTeX-imenu-create-index-function)

  ;; Initialization of `add-log-current-defun-function':
  (setq-local add-log-current-defun-function #'TeX-current-defun-name)

  ;; Set LaTeX-specific help messages for error so that it's available
  ;; in `TeX-help-error'.
  (setq-local TeX-error-description-list-local
              LaTeX-error-description-list))

(defun LaTeX-imenu-create-index-function ()
  "Return an alist for Imenu support for LaTeX.
The returned alist is built by the same facilities used for outline
minor mode support.  Hence, the value of `TeX-outline-extra' is
respected."
  (TeX-update-style)
  (let (entries
        (regexp (LaTeX-outline-regexp)))
    (goto-char (point-max))
    (while (re-search-backward regexp nil t)
      (let* ((name (LaTeX-outline-name))
             (level (make-string (1- (LaTeX-outline-level)) ?\ ))
             (label (concat level level name))
             (mark (make-marker)))
        (set-marker mark (point))
        (set-text-properties 0 (length label) nil label)
        (setq entries (cons (cons label mark) entries))))
    entries))

(defvar LaTeX-builtin-opts
  '("12pt" "11pt" "10pt" "twocolumn" "twoside" "draft")
  "Built in options for LaTeX standard styles.")

(defun LaTeX-209-to-2e ()
  "Make a stab at changing 2.09 doc header to 2e style."
  (interactive)
  (TeX-home-buffer)
  (let (optstr optlist 2eoptlist 2epackages docline docstyle)
    (goto-char (point-min))
    (if
        (search-forward-regexp
         "\\\\documentstyle\\[\\([^]]*\\)\\]{\\([^}]*\\)}"
         (point-max) t)
        (setq optstr (TeX-match-buffer 1)
              docstyle (TeX-match-buffer 2)
              optlist (split-string optstr ","))
      (if (search-forward-regexp
           "\\\\documentstyle{\\([^}]*\\)}"
           (point-max) t)
          (setq docstyle (TeX-match-buffer 1))
        (error "No documentstyle defined")))
    (beginning-of-line 1)
    (setq docline (point))
    (insert "%%%")
    (while optlist
      (if (member (car optlist) LaTeX-builtin-opts)
          (setq 2eoptlist (cons (car optlist) 2eoptlist))
        (setq 2epackages (cons (car optlist) 2epackages)))
      (setq optlist (cdr optlist)))
    ;;(message (format "%S %S" 2eoptlist 2epackages))
    (goto-char docline)
    (forward-line 1)
    (insert "\\documentclass")
    (if 2eoptlist
        (insert "["
                (mapconcat (lambda (x) x)
                           (nreverse 2eoptlist) ",") "]"))
    (insert "{" docstyle "}\n")
    (if 2epackages
        (insert "\\usepackage{"
                (mapconcat (lambda (x) x)
                           (nreverse 2epackages) "}\n\\usepackage{") "}\n"))
    (if (equal docstyle "slides")
        (progn
          (goto-char (point-min))
          (while (re-search-forward "\\\\blackandwhite{" nil t)
            (replace-match "\\\\input{" nil nil)))))
  (TeX-normal-mode nil))

;; This function is no longer used; We leave it for compatibility.
(defun LaTeX-env-beginning-pos-col ()
  "Return a cons: (POINT . COLUMN) for current environment's beginning."
  (save-excursion
    (LaTeX-find-matching-begin)
    (cons (point) (current-column))))

;; This makes difference from `LaTeX-env-beginning-pos-col' when
;; something non-whitespace sits before the \begin{foo}.  (bug#65648)
(defun LaTeX-env-beginning-pos-indent ()
  "Return a cons: (POINT . INDENT) for current environment's beginning.
INDENT is the indent of the line containing POINT."
  (save-excursion
    ;; FIXME: There should be some fallback mechanism in case that the
    ;; next `backward-up' fails.  (Such fail can occur in document
    ;; with temporarily broken structure due to in-progress editing
    ;; process.)
    (LaTeX-backward-up-environment)
    (cons (point) (LaTeX-current-indentation))))

(defun LaTeX-hanging-ampersand-position (&optional pos col)
  "Return indent column for a hanging ampersand (that is, ^\\s-*&).
When you know the position of the beginning of the current
environment and indent of its line, supply them as optional
arguments POS and COL for efficiency."
  (cl-destructuring-bind
      (beg-pos . beg-col)
      (if pos
          (cons pos col)
        (LaTeX-env-beginning-pos-indent))
    (let ((cur-pos (point)))
      (save-excursion
        (if (and (search-backward "\\\\" beg-pos t)
                 ;; Give up if the found "\\" belongs to an inner env.
                 (= beg-pos
                    (save-excursion
                      (LaTeX-find-matching-begin)
                      (point))))
            ;; FIXME: This `how-many' fails to count correctly if
            ;; there is an inner env with "&" but without "\\", e.g.
            ;; \begin{pmatrix}
            ;;   a & b
            ;; \end{pmatrix}
            (let ((cur-idx (how-many "[^\\]&" (point) cur-pos)))
              (goto-char beg-pos)
              ;; FIXME: This regex search fails if there is an inner
              ;; env with "&" in it.
              (if (re-search-forward "[^\\]&" cur-pos t (+ 1 cur-idx))
                  (- (current-column) 1)
                ;; If the above searchs fails, i.e. no "&" found,
                ;; (- (current-column) 1) returns -1, which is wrong.
                ;; So we use a fallback (+ 2 beg-col) whenever this
                ;; happens:
                (+ 2 beg-col)))
          (+ 2 beg-col))))))

(defun LaTeX-indent-tabular ()
  "Return indent column for the current tabular-like line."
  (cl-destructuring-bind
      (beg-pos . beg-col)
      (LaTeX-env-beginning-pos-indent)
    (let ((tabular-like-end-regex
           (format "\\\\end{%s}"
                   (regexp-opt
                    (let (out)
                      (mapc (lambda (x)
                              (when (eq (cadr x) #'LaTeX-indent-tabular)
                                (push (car x) out)))
                            LaTeX-indent-environment-list)
                      out)))))
      (cond ((looking-at tabular-like-end-regex)
             beg-col)

            ((looking-at "\\\\\\\\")
             (+ 2 beg-col))

            ((looking-at "&")
             (LaTeX-hanging-ampersand-position beg-pos beg-col))

            (t
             (+ 2
                (let ((any-col
                       (save-excursion
                         (when
                             (catch 'found
                               ;; Search "\\" or "&" which belongs to
                               ;; the current env, not an inner env.
                               (while (re-search-backward
                                       "\\\\\\\\\\|[^\\]&" beg-pos t)
                                 (let ((p (point)))
                                   (when (= beg-pos
                                            (progn
                                              (LaTeX-find-matching-begin)
                                              (point)))
                                     ;; It belongs to the current env.
                                     ;; Go to target position and exit
                                     ;; the loop.
                                     (goto-char (1+ p))
                                     (throw 'found t)
                                     ;; Otherwise it belongs to an
                                     ;; inner env, so continue the
                                     ;; loop.
                                     ))))
                           ;; If we found "&", then use its column as
                           ;; `any-col'.  Else, `any-col' will be nil.
                           (if (= ?& (char-after))
                                  (current-column))))))
                  (or any-col
                      beg-col))))))))

;; Utilities:

(defmacro LaTeX-check-insert-macro-default-style (&rest body)
  "Check for values of `TeX-insert-macro-default-style' and `current-prefix-arg'.
This is a utility macro with code taken from `TeX-parse-arguments'.  It
should be used inside more complex function within AUCTeX style files
where optional and mandatory arguments are queried and inserted.  For
example, check the function `LaTeX-arg-bicaption-bicaption'
defined in style/bicaption.el."
  `(unless (if (eq TeX-insert-macro-default-style 'show-all-optional-args)
               (equal current-prefix-arg '(4))
             (or
              (and (eq TeX-insert-macro-default-style 'show-optional-args)
                   (equal current-prefix-arg '(4)))
              (and (eq TeX-insert-macro-default-style 'mandatory-args-only)
                   (null (equal current-prefix-arg '(4))))
              TeX-last-optional-rejected))
     ,@body))

(defun LaTeX-extract-key-value-label (&optional key num)
  "Return a regexp string to match a label in an optional argument.
The optional KEY is a string which is the name of the key in the
key=value, default is \"label\".  NUM is an integer for an
explicitly numbered group construct, useful when adding items to
`reftex-label-regexps'.

As an extra feature, the key can be the symbol `none' where the
entire matching for the key=value is skipped.  The regexp then is
useful for skipping complex optional arguments.  It should be
wrapped in \\(?:...\\)? then."
  ;; The regexp produced here is ideally in sync with the complex one
  ;; in `reftex-label-regexps'.
  (concat
   ;; Match the opening [ and the following chars
   "\\[[^][]*"
   ;; Allow nested levels of chars enclosed in braces
   "\\(?:{[^}{]*"
     "\\(?:{[^}{]*"
       "\\(?:{[^}{]*}[^}{]*\\)*"
     "}[^}{]*\\)*"
   "}[^][]*\\)*"
   ;; If KEY is the symbol none, don't look for any key=val:
   (unless (eq key 'none)
     (concat "\\<"
             ;; Match the key, default is label
             (or key "label")
             ;; Optional spaces
             "[[:space:]]*=[[:space:]]*"
             ;; Match the value; braces around the value are optional
             "{?\\("
             ;; Cater for NUM which sets the regexp group
             (when (and num (integerp num))
               (concat "?" (number-to-string num) ":"))
             ;; One of these chars terminates the value
             "[^] ,}\r\n\t%]+"
             ;; Close the group
             "\\)}?"))
   ;; We are done.  Just search until the next closing bracket
   "[^]]*\\]"))

(defun LaTeX-keyval-caption-reftex-context-function (env)
  "Extract and return a key=val caption context string for RefTeX in ENV.
ENV is the name of current environment passed to this function by
RefTeX.  The context string is the value given to the caption key.  If
no caption key is found, an error is issued.  See also the docstring of
`reftex-label-alist' and its description for CONTEXT-METHOD."
  (let* ((envstart (save-excursion
                     (re-search-backward (concat "\\\\begin{" env "}")
                                         nil t)))
         (capt-key (save-excursion
                     (re-search-backward "\\<caption[ \t\n\r%]*=[ \t\n\r%]*"
                                         envstart t)))
         capt-start capt-end)
    (if capt-key
        (save-excursion
          (goto-char (match-end 0))
          (cond ((looking-at-p (regexp-quote (concat TeX-grop LaTeX-optop)))
                 ;; Short caption inside [] is available, extract it only
                 (forward-char)
                 (setq capt-start (1+ (point)))
                 (setq capt-end (1- (progn (forward-sexp) (point)))))
                ;; Extract the entire caption which is enclosed in braces
                ((looking-at-p TeX-grop)
                 (setq capt-start (1+ (point)))
                 (setq capt-end (1- (progn (forward-sexp) (point)))))
                ;; Extract everything to next comma ,
                (t
                 (setq capt-start (point))
                 (setq capt-end (progn (skip-chars-forward "^,") (point)))))
          ;; Return the extracted string
          (buffer-substring-no-properties capt-start capt-end))
      (error "%s" "No caption found"))))

(defvar LaTeX-font-family '("normalfont" "rmfamily"
                            "sffamily"   "ttfamily")
  "List of LaTeX font family declarations.")

(defvar LaTeX-font-series '("mdseries" "bfseries")
  "List of LaTeX font series declarations.")

(defvar LaTeX-font-shape '("itshape" "slshape"  "scshape"  "sscshape"
                           "swshape" "ulcshape" "upshape")
  "List of LaTeX font shape declarations.")

(defvar LaTeX-font-size '("tiny" "scriptsize" "footnotesize" "small"
                          "normalsize" "large" "Large"
                          "LARGE" "huge" "Huge")
  "List of LaTeX font size declarations.")

(defun LaTeX--strip-labels ()
  "Remove label commands between point and end of buffer."
  (let ((re (concat
             "\\(?:"
             (if (bound-and-true-p reftex-label-regexps)
                 (mapconcat #'identity reftex-label-regexps "\\|")
               (format "%slabel%s%s%s"
                       (regexp-quote TeX-esc)
                       TeX-grop "[^}]*" TeX-grcl))
             "\\)")))
    (save-excursion
      (while (re-search-forward re nil t)
        (replace-match "")))))

(defun LaTeX--modify-math-1 (open close inline new-open new-close new-inline pos)
  "Helper function for `LaTeX-modify-math'.
OPEN and CLOSE are the current delimiters, NEW-OPEN and NEW-CLOSE are
the new delimiters.  INLINE and NEW-INLINE are booleans indicating
whether the current and new delimiters are inline or display math.
Assume point is at the start of the current OPEN delimiter.  POS is a
marker that keeps track of cursor position."
  (let ((converting-to-inline (and (not inline) new-inline)))
    (when converting-to-inline
      ;; Join with previous line if non-blank.
      (when (save-excursion
              (skip-chars-backward "[:blank:]")
              (and
               (bolp) (not (bobp))
               (progn
                 (forward-char -1)
                 (skip-chars-backward "[:blank:]")
                 (not (bolp)))))
        ;; The following dance gets around the slightly counterintuitive
        ;; behavior of (save-excursion (join-line)) with point at bol.
        (forward-char (length open))
        (save-excursion (join-line))
        (forward-char (- (length open)))))
    (unless new-inline
      ;; Ensure non-inline delimiters start on a blank line.
      (unless (save-excursion
                (skip-chars-backward "[:blank:]")
                (and
                 (bolp) (not (bobp))))
        (delete-horizontal-space)
        (insert "\n")))
    ;; Delete opening delimiter.
    (delete-char (length open))
    (let ((start (point)))
      (search-forward close)
      (when converting-to-inline
        ;; Join with next line if non-blank.
        (when (and (looking-at-p "[[:blank:]]*\n")
                   (save-excursion
                     (forward-line 1)
                     (not (looking-at-p "^[[:blank:]]*$"))))
          (join-line 'next)))
      (unless new-inline
        (unless (looking-at-p "[[:blank:]]*\n")
          (save-excursion
            (insert "\n"))))
      ;; Delete closing delimiter.
      (delete-char (- (length close)))
      (save-restriction
        (narrow-to-region start (point))
        ;; Clear labels.
        (goto-char (point-min))
        (LaTeX--strip-labels)
        ;; Delete leading and trailing whitespace.
        (dolist (re '("\\`[ \t\n\r]+" "[ \t\n\r]+\\'"))
          (goto-char (point-min))
          (when (re-search-forward re nil t)
            (replace-match "")))
        (unless new-inline
          (goto-char (point-min))
          (insert "\n")
          (goto-char (point-max))
          (insert "\n"))
        ;; Insert new opening delimiter.
        (goto-char (point-min))
        (insert new-open)
        ;; Insert new closing delimiter
        (goto-char (point-max))
        (when (= (point) pos)
          (set-marker-insertion-type pos (not 'advance)))
        (when converting-to-inline
          (skip-chars-backward ".,;:!?"))
        (insert new-close)
        ;; Indent, including one line past the modified region.
        (widen)
        (end-of-line 2)
        (indent-region start (point))))))

(defun LaTeX--math-environment-list ()
  "Return list of defined math environments.
This combines the env-on entries from `texmathp' and any user additions."
  (texmathp-compile)
  (mapcar #'car
          (cl-remove-if-not
           (lambda (entry)
             (eq (nth 1 entry) 'env-on))
           texmathp-tex-commands1)))

(defun LaTeX--closing (type)
  "Return closing delimiter corresponding to given `texmathp' TYPE.
TYPE must be one of the (La)TeX symbols $, $$, \\( or \\=\\[, or a valid
environment name.  Macros such as \\ensuremath are not supported."
  (pcase type
    ((or "$" "$$") type)
    ("\\[" "\\]")
    ("\\(" "\\)")
    (_ (unless (member type (LaTeX--math-environment-list))
         (error "Invalid or unsupported opening delimiter: %s" type))
       (concat TeX-esc "end" TeX-grop type TeX-grcl))))

(defun LaTeX-modify-math (new-type)
  "Modify the current math construct to NEW-TYPE.

Interactively, prompt for NEW-TYPE from a list of inline math
delimiters (\"$\", \"\\(\"), display math delimiters (\"$$\",
\"\\=\\[\") and valid LaTeX environments (\"equation\", ...).

Non-interactively, NEW-TYPE must be either
- a string specifying the target delimiter or environment name, or
- a cons cell ((OPEN . CLOSE) . INLINE), where OPEN and CLOSE are
  delimiters and INLINE is non-nil if the math construct is to be
  understood as inline.

The function converts the math construct at point (inline, display, or
environment) to the specified NEW-TYPE, preserving the content.  If
point is not in a math construct, signal an error.  Clears any active
previews at point before modification.

Does not support modifying macro-based constructs such as \\ensuremath."
  ;; FIXME: this function may not work correctly in docTeX
  (interactive
   (let ((type (progn (texmathp) (car texmathp-why)))
         (tbl (append '("$" "\\(" "$$" "\\[")
                      (LaTeX--math-environment-list))))
     (barf-if-buffer-read-only)
     (unless type (user-error "Not inside math"))
     (LaTeX--closing type) ;; Check for errors.
     (list (completing-read
            (format "Convert %s → " type) tbl nil t nil nil
            type))))
  (let ((new-open (if (stringp new-type)
                      new-type
                    (caar new-type)))
        (new-close (if (stringp new-type)
                       (LaTeX--closing new-type)
                     (cdar new-type)))
        (new-inline (if (stringp new-type)
                        (member new-type '("$" "\\("))
                      (cdr new-type))))
    (when (fboundp 'preview-clearout-at-point)
      (preview-clearout-at-point))
    (unless (called-interactively-p 'any)
      (unless (texmathp) (error "Not inside math")))
    (let ((type (car texmathp-why))
          (math-start (cdr texmathp-why))
          (pos (point-marker)))
      (set-marker-insertion-type pos
                                 (not
                                  (and
                                   (< (point) (point-max))
                                   (save-excursion
                                     (forward-char)
                                     (not (texmathp))))))
      (goto-char math-start)
      (let ((open (if (member type '("\\(" "$" "\\[" "$$"))
                      type
                    (concat TeX-esc "begin" TeX-grop type TeX-grcl)))
            (close (LaTeX--closing type)))
        (if (or (not (stringp new-type))
                (member new-open '("$" "\\(" "\\[" "$$")))
            ;; Conversion to inline or non-environment display.
            (let ((inline (member type '("$" "\\("))))
              (LaTeX--modify-math-1 open close inline new-open new-close new-inline pos))
          ;; Conversion to an environment.
          (delete-char (length open))
          (push-mark (save-excursion
                       (search-forward close)
                       (delete-region (match-beginning 0) (match-end 0))
                       (when (= (point) pos)
                         (set-marker pos nil)
                         (setq pos nil))
                       (when (member type '("$" "\\("))
                         (skip-chars-forward ".,;:!?"))
                       (point)))
          (activate-mark)
          (LaTeX-insert-environment new-type)))
      (when pos
        (goto-char pos)
        (set-marker pos nil)))))

(defun LaTeX-make-inline ()
  "Convert LaTeX display math construct at point to inline math.
Remove the enclosing math construct (such as \\=\\[...\\] or
\\begin{equation}...\\end{equation}) and replace it with inline math
surrounded by `TeX-electric-math' if non-nil, or \"$...$\".  Leave any
trailing punctuation outside the math delimiters."
  ;; FIXME: this function may not work correctly in docTeX
  (interactive "*")
  (LaTeX-modify-math
   (if TeX-electric-math
       (cons TeX-electric-math 'inline)
     "$")))

(provide 'latex)

;;; latex.el ends here
