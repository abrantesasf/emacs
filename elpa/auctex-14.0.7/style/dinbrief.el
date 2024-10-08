;;; dinbrief.el --- Special code for LaTeX-Style dinbrief.  -*- lexical-binding: t; -*-

;; Copyright (C) 1994-2024  Free Software Foundation, Inc.

;; Author: Werner Fink <werner@suse.de>
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

;; LaTeX Class: dinbrief.cls

;;; Code:

(require 'tex)
(require 'latex)

;; Silence the compiler:
(declare-function font-latex-add-keywords
                  "font-latex"
                  (keywords class))

(defvar LaTeX-dinbrief-class-options
  '("10pt" "11pt" "12pt" "norm" "a4paper" "a5paper" "b5paper"
    "letterpaper" "legalpaper" "executivepaper" "twoside"
    "addresshigh" "addressstd" "onecolumn" "twocolumn")
  "Class options for the dinbrief class.")

(TeX-add-style-hook
 "dinbrief"
 (lambda ()
   (LaTeX-add-environments
    '("letter" LaTeX-dinbrief-env-recipient)
    "dinquote")
   (add-hook 'LaTeX-document-style-hook
             #'LaTeX-dinbrief-style)
   (setq LaTeX-default-document-environment "letter")
   (TeX-add-symbols
    '("address" "Absender")
    '("postremark" "Postvermerk")
    '("date" "Datum")
    '("subject" "Betreff")
    '("handling" "Behandlungsvermerk")
    '("cc" "Verteiler")
    '("place" "Heutiger Ort")
    "makelabels"
    "nowindowrules"
    "windowrules"
    "nowindowtics"
    "windowtics"
    "disabledraftstandard"
    "enabledraftstandard"
    "centeraddress"
    "normaladdress"
    '("encl" "Anlagen: ")
    '("backaddress" "Retouradresse")
    '("signature" "Unterschrift")
    '("opening" "Anrede")
    '("closing" "Schluss"))

   ;; Fontification
   (when (and (featurep 'font-latex)
              (eq TeX-install-font-lock 'font-latex-setup))
     (font-latex-add-keywords '(("subject" "{")
                                ("address" "{")
                                ("signature" "{")
                                ("opening" "{")
                                ("closing" "{")
                                ("location" "{")
                                ("handling" "{")
                                ("cc" "{")
                                ("encl" "{")
                                ("ps" "{"))
                              'function)))
 TeX-dialect)

(defmacro LaTeX-dinbrief-insert (&rest args)
  "Insert text ignoring active markers."
  `(progn
     (if (TeX-active-mark) (deactivate-mark))
     (insert ,@args)))

(defun LaTeX-dinbrief-style ()
  "Insert some useful packages for writing german letters."
  (save-excursion
    (goto-char (point-min)) ; insert before \begin{document}
    (if (re-search-forward ".begin.document." (point-max) t)
        (beginning-of-line 1))
    (open-line 2)
    (indent-relative-first-indent-point)
    (LaTeX-dinbrief-insert TeX-esc "usepackage"
                           LaTeX-optop "T1" LaTeX-optcl
                           TeX-grop "fontenc" TeX-grcl)
    (newline-and-indent)
    (LaTeX-dinbrief-insert TeX-esc "usepackage"
                           LaTeX-optop "ngerman" LaTeX-optcl
                           TeX-grop "babel" TeX-grcl))
  (TeX-run-style-hooks "fontenc" "babel"))

(defun LaTeX-dinbrief-env-recipient (environment)
  "Insert ENVIRONMENT and prompt for recipient and address."
  (let ((sender (LaTeX-dinbrief-sender))
        (recipient (TeX-read-string "Empfänger: "))
        (address (LaTeX-dinbrief-recipient))
        (date (TeX-read-string "Datum: " (LaTeX-dinbrief-today)))
        (postremark (TeX-read-string "Postvermerk: "))
        (fenster (TeX-read-string "Fenster (ja/nein): "))
        (vermerk (TeX-read-string "Behandlungsvermerk: "))
        (verteil (TeX-read-string "Verteiler: "))
        (betreff (TeX-read-string "Betreff: "))
        (opening (TeX-read-string "Anrede: "))
        (closing (TeX-read-string "Schluss: "))
        (signature (TeX-read-string "Unterschrift: "))
        (anlage (TeX-read-string "Anlagen: ")))
    (if (string= fenster "ja")
        (progn
          (LaTeX-dinbrief-insert TeX-esc "enabledraftstandard")
          (newline-and-indent)
          (LaTeX-dinbrief-insert TeX-esc "centeraddress")
          (newline-and-indent)
          (LaTeX-dinbrief-insert TeX-esc "nowindowrules")
          (newline-and-indent)
          (LaTeX-dinbrief-insert TeX-esc "windowtics")
          (newline-and-indent)
          (let ((retouradr (TeX-read-string "Retouradresse: " sender)))
            (newline-and-indent)
            (if (not (zerop (length retouradr)))
                (progn
                  (if (TeX-active-mark) (deactivate-mark))
                  (LaTeX-dinbrief-insert TeX-esc
                                         "backaddress"
                                         TeX-grop retouradr TeX-grcl)
                  (newline-and-indent)))))
      (LaTeX-dinbrief-insert TeX-esc "enabledraftstandard")
      (newline-and-indent)
      (LaTeX-dinbrief-insert TeX-esc "centeraddress")
      (newline-and-indent)
      (LaTeX-dinbrief-insert TeX-esc "nowindowrules")
      (newline-and-indent)
      (LaTeX-dinbrief-insert TeX-esc "windowtics"))
    (newline-and-indent)
    (if (not (zerop (length signature)))
        (progn
          (LaTeX-dinbrief-insert TeX-esc "signature" TeX-grop signature TeX-grcl)
          (newline-and-indent)))
    (if (not (zerop (length date)))
        (progn
          (LaTeX-dinbrief-insert TeX-esc "date" TeX-grop date TeX-grcl)
          (newline-and-indent)))
    (newline-and-indent)

    (let ((indentation (current-column)))
      (LaTeX-insert-environment
       environment
       (concat TeX-grop recipient
               (if (not (zerop (length address)))
                   (concat
                    (if (not (zerop (length recipient)))
                        (concat " " TeX-esc TeX-esc " "))
                    address))
               TeX-grcl))
      (save-excursion                   ; Fix indentation of address
        (if (search-backward TeX-grcl nil 'move)
            (let ((addr-end (point-marker)))
              (if (search-backward TeX-grop nil 'move)
                  (let ((addr-column (current-column)))
                    (while (search-forward
                            (concat TeX-esc TeX-esc)
                            (marker-position addr-end) 'move)
                      (progn
                        (newline)
                        (indent-to addr-column)))))
              (set-marker addr-end nil))))
      (LaTeX-dinbrief-insert "\n")
      (indent-to indentation))
    (if (not (zerop (length postremark)))
        (progn
          (LaTeX-dinbrief-insert TeX-esc "postremark" TeX-grop postremark TeX-grcl)
          (newline-and-indent)))
    (if (not (zerop (length betreff)))
        (progn
          (LaTeX-dinbrief-insert TeX-esc "subject" TeX-grop)
          (LaTeX-dinbrief-insert betreff TeX-grcl)
          (newline-and-indent)))
    (if (not (zerop (length vermerk)))
        (progn
          (LaTeX-dinbrief-insert TeX-esc "handling" TeX-grop vermerk TeX-grcl)
          (newline-and-indent)))
    (if (not (zerop (length verteil)))
        (progn
          (LaTeX-dinbrief-insert TeX-esc "cc" TeX-grop verteil TeX-grcl)
          (newline-and-indent)))
    (if (not (zerop (length anlage)))
        (progn
          (LaTeX-dinbrief-insert TeX-esc "encl" TeX-grop anlage TeX-grcl)
          (newline-and-indent)))
    (LaTeX-dinbrief-insert TeX-esc "opening"
                           TeX-grop
                           (if (zerop (length opening))
                               (concat TeX-esc " ")
                             opening)
                           TeX-grcl "\n")

    (indent-relative-first-indent-point)
    (save-excursion
      (LaTeX-dinbrief-insert "\n" TeX-esc "closing"
                             TeX-grop
                             (if (zerop (length closing))
                                 (concat TeX-esc " ")
                               closing)
                             TeX-grcl "\n")
      (indent-relative-first-indent-point))))

(defun LaTeX-dinbrief-sender ()
  "Read and write the senders address."
  (interactive)
  (let ((name (TeX-read-string "Absender: " (user-full-name)))
        (str  (TeX-read-string "Meine Strasse: "))
        (ort  (TeX-read-string "Mein Wohnort: ")))
    (if (not (zerop (length name)))
        (progn
          (goto-char (point-min)) ; insert before \end{document}
          (if (re-search-forward ".end.document." (point-max) t)
              (beginning-of-line 1))
          (forward-line -1)
          (LaTeX-dinbrief-insert TeX-esc "address" TeX-grop name)
          (if (not (zerop (length str)))
              (progn
                (LaTeX-dinbrief-insert " " TeX-esc TeX-esc)
                (newline-and-indent)
                (LaTeX-dinbrief-insert str)))
          (if (not (zerop (length ort)))
              (progn
                (LaTeX-dinbrief-insert " " TeX-esc "par")
                (newline-and-indent)
                (LaTeX-dinbrief-insert ort)))
          (LaTeX-dinbrief-insert TeX-grcl)
          (newline-and-indent)
          (concat name ", " str ", " ort)))))

(defun LaTeX-dinbrief-recipient ()
  "Read and return the recipient address."
  (interactive)
  (let ((str  (TeX-read-string "Wohnhaft in Strasse: "))
        (ort  (TeX-read-string "Aus der Ortschaft: ")))
    (if (not (zerop (length str)))
        (if (not (zerop (length ort)))
            (concat str " " TeX-esc TeX-esc " " ort)
          str)
      (if (not (zerop (length ort)))
          ort))))

(defun LaTeX-dinbrief-today ()
  "Return a string representing todays date according to flavor."
  (interactive)
  (let ((ctime-string (current-time-string))
        (month-alist '(("Jan" . "Januar")
                       ("Feb" . "Februar")
                       ("Mar" . "März")
                       ("Apr" . "April")
                       ("May" . "Mai")
                       ("Jun" . "Juni")
                       ("Jul" . "Juli")
                       ("Aug" . "August")
                       ("Sep" . "September")
                       ("Oct" . "Oktober")
                       ("Nov" . "November")
                       ("Dec" . "Dezember"))))
    (string-match
     "^\\S-+\\s-+\\(\\S-+\\)\\s-+\\(\\S-+\\)\\s-+\\S-+\\s-+\\(\\S-+\\)"
     ctime-string)
    (let ((year (substring ctime-string (match-beginning 3) (match-end 3)))
          (month (substring ctime-string (match-beginning 1) (match-end 1)))
          (day (substring ctime-string (match-beginning 2) (match-end 2)))
          (place (TeX-read-string "Heutiger Ort: ")))
      (if (assoc month month-alist)
          (progn
            (setq month (cdr (assoc month month-alist)))
            (if (> 2 (length day))
                (setq day (concat "0" day)))))
      (format "%s, den %s. %s %s" place day month year))))

;; Local Variables:
;; coding: utf-8-unix
;; End:

;;; dinbrief.el ends here
