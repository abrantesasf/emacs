;;; graphicx.el --- AUCTeX style file for graphicx.sty  -*- lexical-binding: t; -*-

;; Copyright (C) 2000--2024 by Free Software Foundation, Inc.

;; Author: Ryuichi Arafune <arafune@debian.org>
;; Created: 1999/3/20
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

;;  This package supports the includegraphics macro in graphicx style.

;; Acknowledgements
;;  Dr. Thomas Baumann <thomas.baumann@ch.tum.de>
;;  David Kastrup <David.Kastrup@t-online.de>
;;  Masayuki Ataka <masayuki.ataka@gmail.com>

;;; Code:

(require 'crm)
(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(defvar LaTeX-graphicx-key-val-options
  '(("bb")
    ("bbllx")
    ("bblly")
    ("bburx")
    ("bbury")
    ("natheight")
    ("natwidth")
    ("viewport")
    ("trim")
    ("hiresbb" ("true" "false"))
    ("angle")
    ("origin")
    ("width"           ("\\textwidth" "\\columnwidth" "\\linewidth"))
    ("height"          ("\\textheight"))
    ("totalheight"     ("\\textheight"))
    ("keepaspectratio" ("true" "false"))
    ("scale")
    ("clip"  ("true" "false"))
    ("draft" ("true" "false"))
    ("quiet")
    ("interpolate" ("true" "false"))
    ("alt"))
  "Key=value options for graphicx macros.")

(defun LaTeX-graphicx-key-val-options ()
  "Return an updated list of key=vals from graphicx package.
If `TeX-engine' is set to symbol `default' (while
`TeX-PDF-from-DVI' is set to nil) or `luatex' and `TeX-PDF-mode'
is non-nil, add the keys \"page\" and \"pagebox\" to list of
key=vals."
  (if (and (or (and (eq TeX-engine 'default)
                    (not (TeX-PDF-from-DVI)))
               (eq TeX-engine 'luatex)
               ;; dvipdfmx can handle page and
               ;; pagebox options.
               (string= (TeX-PDF-from-DVI) "Dvipdfmx"))
           TeX-PDF-mode)
      (append '(("page")
                ("pagebox" ("mediabox" "cropbox" "bleedbox"
                            "trimbox" "artbox")))
              LaTeX-graphicx-key-val-options)
    LaTeX-graphicx-key-val-options))

(defvar LaTeX-includegraphics-dvips-extensions
  '("eps" "mps" "EPS")
  "List of extensions for image files supported by \"dvips\".")

(defvar LaTeX-includegraphics-pdftex-extensions
  '("png" "pdf" "jpg" "jpeg" "jbig2" "jb2" "mps"
    "PNG" "PDF" "JPG" "JPEG" "JBIG2" "JB2")
  "List of extensions for image files supported by \"pdftex\" and \"luatex\".")

(defvar LaTeX-includegraphics-xetex-extensions
  '("pdf" "eps" "mps" "ps" "png" "jpg" "jpeg" "jp2" "jpf"
    "PDF" "EPS" "MPS" "PS" "PNG" "JPG" "JPEG" "JP2" "JPF"
    "bmp" "pict" "psd" "mac" "tga" "gif" "tif" "tiff"
    "BMP" "PICT" "PSD" "MAC" "TGA" "GIF" "TIF" "TIFF")
  "List of extensions for image files supported by \"xetex\".")

(defun LaTeX-includegraphics-extensions-list ()
  "Return appropriate extensions for input files to \\includegraphics.
Return value is a list of regexps."
  (let ((temp (copy-sequence LaTeX-includegraphics-extensions)))
    (cond (;; 'default TeX-engine:
           (eq TeX-engine 'default)
           (if ;; we want to produce a pdf
               (if TeX-PDF-mode
                   ;; Return t if default compiler produces PDF,
                   ;; nil for "Dvips" or "Dvipdfmx"
                   (not (TeX-PDF-from-DVI))
                 ;; t if pdftex is used in dvi-mode
                 TeX-DVI-via-PDFTeX)
               ;; We're using pdflatex in pdf-mode
               (TeX-delete-duplicate-strings
                (append LaTeX-includegraphics-pdftex-extensions
                        temp))
             ;; We're generating a .dvi to process with dvips or dvipdfmx
             (progn
               ;; dvipdfmx can handle jpeg, pdf and png for image formats.
               (unless (and TeX-PDF-mode
                            (string= (TeX-PDF-from-DVI) "Dvipdfmx"))
                 (dolist (x '("jpe?g" "pdf" "png"))
                   (setq temp (delete x temp))))
               (TeX-delete-duplicate-strings
                (append LaTeX-includegraphics-dvips-extensions
                        temp)))))
          ;; Running luatex in pdf or dvi-mode:
          ((eq TeX-engine 'luatex)
           (if TeX-PDF-mode
               (TeX-delete-duplicate-strings
                (append LaTeX-includegraphics-pdftex-extensions
                        temp))
             (progn
               (dolist (x '("jpe?g" "pdf" "png"))
                 (setq temp (delete x temp)))
               (TeX-delete-duplicate-strings
                (append LaTeX-includegraphics-dvips-extensions
                        temp)))))
          ;; Running xetex in any mode:
          ((eq TeX-engine 'xetex)
           (TeX-delete-duplicate-strings
            (append LaTeX-includegraphics-xetex-extensions
                    temp)))
          ;; For anything else
          (t
           (if (and TeX-PDF-mode
                    (string= (TeX-PDF-from-DVI) "Dvipdfmx"))
               ;; dvipdfmx can handle the same image formats as dvips.
               (TeX-delete-duplicate-strings
                (append LaTeX-includegraphics-dvips-extensions
                        temp))
             temp)))))

(defun LaTeX-includegraphics-extensions (&optional list)
  "Return appropriate extensions for input files to \\includegraphics.
Return value is a single regexp.
Optional argument LIST if non-nil is used as list of regexps of
extensions to be matched."
  (unless list
    (setq list (LaTeX-includegraphics-extensions-list)))
  (concat "\\." (mapconcat #'identity list "\\'\\|\\.") "\\'"))

(defvar LaTeX-includegraphics-global-files nil
  "List of the non-local graphic files to include in LaTeX documents.
Initialized once at the first time you prompt for an input file.
May be reset with `\\[universal-argument] \\[TeX-normal-mode]'.")

;; Add the variable to `TeX-normal-mode-reset-list':
(add-to-list 'TeX-normal-mode-reset-list 'LaTeX-includegraphics-global-files)

(defun LaTeX-parse-graphicspath ()
  "Parse the current document for \\graphicspath commands.
Return value is a list of paths."
  (let ((results '())
        (graphicspath-regex "\\\\graphicspath{\\({\\([^}]*\\)}\\)*}")
        (single-path-regex "{\\([^{}]*\\)}"))
    (save-excursion
      (save-restriction
        (widen)
        (goto-char (point-min))
        (while (re-search-forward graphicspath-regex nil t)
          (let ((start-pos (match-beginning 0))
                (end-pos (match-end 0)))
            (save-excursion
              (goto-char start-pos)
              (while (re-search-forward single-path-regex end-pos t)
                (push (match-string-no-properties 1) results)))))
        (nreverse results)))))

(defun LaTeX-includegraphics-read-file-TeX ()
  "Read image file for \\includegraphics.
Offers all graphic files found in the TeX search path.  See
`LaTeX-includegraphics-read-file' for more."
  (let ((LaTeX-includegraphics-extensions
         (LaTeX-includegraphics-extensions-list))
        (extra-dirs (LaTeX-parse-graphicspath)))
    (unless LaTeX-includegraphics-global-files
      (message "Searching for graphic files...")
      (setq LaTeX-includegraphics-global-files
            (TeX-search-files-by-type
             'graphics 'global t
             LaTeX-includegraphics-strip-extension-flag))
      (message "Searching for graphic files...done"))
    (completing-read
     "Image file: "
     (append
      (TeX-search-files-by-type 'graphics 'local t
                                LaTeX-includegraphics-strip-extension-flag
                                extra-dirs)
      LaTeX-includegraphics-global-files)
     nil nil nil)))

(defun LaTeX-includegraphics-read-file-relative ()
  "Read image file for \\includegraphics.

Lists all graphic files in the master directory and its
subdirectories and inserts the relative file name.  See
`LaTeX-includegraphics-read-file' for more."
  (file-relative-name
   (read-file-name
    "Image file: " nil nil nil nil
    (lambda (fname)
      (or (file-directory-p fname)
          (string-match (LaTeX-includegraphics-extensions) fname))))
   (TeX-master-directory)))

(defun LaTeX-arg-includegraphics (optional)
  "Ask for mandantory argument for the \\includegraphics command."
  (let ((image-file (funcall LaTeX-includegraphics-read-file)))
    (TeX-argument-insert
     (if LaTeX-includegraphics-strip-extension-flag
         (replace-regexp-in-string (LaTeX-includegraphics-extensions)
                                   ""
                                   image-file)
       image-file)
     optional)))

(TeX-add-style-hook
 "graphicx"
 (lambda ()
   (TeX-add-symbols
    '("reflectbox" "Argument")

    `("resizebox"
      (TeX-arg-completing-read
       ,(lambda () (append '("\\width" "!")
                           (mapcar
                            (lambda (x) (concat TeX-esc (car x)))
                            (LaTeX-length-list))))
       "Width")
      (TeX-arg-completing-read
       ,(lambda () (append '("\\height" "\\totalheight" "\\depth" "!")
                           (mapcar
                            (lambda (x) (concat TeX-esc (car x)))
                            (LaTeX-length-list))))
       "Height")
      "Argument")

    `("resizebox*"
      (TeX-arg-completing-read
       (lambda () (append '("\\width" "!")
                          (mapcar
                           (lambda (x) (concat TeX-esc (car x)))
                           (LaTeX-length-list))))
       "Width")
      (TeX-arg-completing-read
       (lambda () (append '("\\height" "\\totalheight" "\\depth" "!")
                          (mapcar
                           (lambda (x) (concat TeX-esc (car x)))
                           (LaTeX-length-list))))
       "Height")
      "Argument")

    '("rotatebox" (TeX-arg-conditional (member "graphics" (TeX-style-list))
                      ()
                    ([TeX-arg-key-val (("x") ("y") ("origin") ("units"))]))
      "Angle" "Argument")

    '("scalebox" "Horizontal scale" [ "Vertical scale" ] "Argument")

    '("includegraphics" (TeX-arg-conditional (member "graphics" (TeX-style-list))
                            (["llx,lly"] ["urx,ury"])
                          ([TeX-arg-key-val (LaTeX-graphicx-key-val-options)
                                            nil nil ?\s]))
      LaTeX-arg-includegraphics)

    '("includegraphics*" (TeX-arg-conditional (member "graphics" (TeX-style-list))
                             (["llx,lly"] ["urx,ury"])
                           ([TeX-arg-key-val (LaTeX-graphicx-key-val-options)
                                             nil nil ?\s]))
      LaTeX-arg-includegraphics)

    '("graphicspath" t)

    '("DeclareGraphicsExtensions"
      (TeX-arg-completing-read-multiple
       (lambda ()
         (delete ".jpe?g" (mapcar (lambda (ext)
                                    (concat "." ext))
                                  (LaTeX-includegraphics-extensions-list))))
       "Extension(s)" nil nil nil nil nil nil nil nil "."))

    '("DeclareGraphicsRule" 4))

   ;; \includegraphics macro should get its own line
   (LaTeX-paragraph-commands-add-locally '("includegraphics"))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("reflectbox" "{")
                                ("resizebox" "*{{{")
                                ("rotatebox" "[{{")
                                ("scalebox" "{[{"))
                              'textual)
     (font-latex-add-keywords '(("includegraphics" "*[[{"))
                              'reference)
     (font-latex-add-keywords '(("graphicspath"              "{")
                                ("DeclareGraphicsExtensions" "{")
                                ("DeclareGraphicsRule"       "{{{{"))
                              'function))

   ;; Option management
   (if (and (LaTeX-provided-package-options-member "graphicx" "dvipdfmx")
            (not (eq TeX-engine 'xetex)))
       (setq TeX-PDF-from-DVI "Dvipdfmx")))
 TeX-dialect)

(defvar LaTeX-graphicx-package-options
  '("draft"       "final"         "debugshow"
    "hiderotate"  "hidescale"     "hiresbb"
    "setpagesize" "nosetpagesize" "demo"
    "dvips"       "xdvi"
    "dvipdf"      "dvipdfm"       "dvipdfmx"
    "xetex"       "pdftex"        "luatex"
    "dvisvgm"     "dvipsone"      "dviwindo"
    "emtex"       "dviwin"        "oztex"
    "textures"    "pctexps"       "pctexwin"
    "pctexhp"     "pctex32"       "truetex"
    "tcidvi"      "vtex")
  "Package options for the graphicx package.")

;;; graphicx.el ends here
