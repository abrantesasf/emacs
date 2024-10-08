;;; tex-mik.el --- MiKTeX support for AUCTeX.  -*- lexical-binding: t; -*-

;; Copyright (C) 1999-2021  Free Software Foundation, Inc.

;; Author: Per Abrahamsen <abraham@dina.kvl.dk>
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
;;
;; This file contains variables customized for MiKTeX.

;;; Code:

(require 'tex)

  ;; Remove the Queue entry from the default, and make a non-Unix
  ;; specific print entry, assuming that we'll print via gsview32.
(unless (get 'TeX-queue-command 'saved-value)
  (setq TeX-queue-command nil))

(unless (get 'TeX-printer-list 'saved-value)
  (setq TeX-printer-list nil))

(unless (get 'TeX-print-command 'saved-value)
  (setq TeX-print-command
        "start \"\" %f"))

(unless (get 'TeX-source-specials-view-position-flags 'saved-value)
  (setq TeX-source-specials-view-position-flags "-s %n%b"))

;; Yap does not support a command line option for inverse searching.
;; The editor command has to be configured inside Yap in
;; "View/Options/Inverse Search" instead.
(unless (get 'TeX-source-specials-view-editor-flags 'saved-value)
  (setq TeX-source-specials-view-editor-flags ""))

;; kpsewhich in MiKTeX (aka findtexmf) does not emit any useful
;; information if fed with kpathsea-related variables anyway.
(unless (get 'TeX-kpathsea-path-delimiter 'saved-value)
  (setq TeX-kpathsea-path-delimiter nil))

(provide 'tex-mik)

;;; tex-mik.el ends here
