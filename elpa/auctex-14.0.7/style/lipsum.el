;;; lipsum.el --- AUCTeX style for `lipsum.sty'.  -*- lexical-binding: t; -*-

;; Copyright (C) 2013, 2020 Free Software Foundation, Inc.

;; Maintainer: auctex-devel@gnu.org
;; Author: Mosè Giordano <giordano.mose@libero.it>
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

;; This file adds support for `lipsum.sty'.

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "lipsum"
 (lambda ()
   (TeX-add-symbols
    '("lipsum" [ "Range of paragraph (max: 150)" ])
    '("lipsum*" [ "Range of paragraph (max: 150)" ])
    '("setlipsumdefault" [ "Default range of paragraph (max: 150)" ])
    '("ChangeLipsumPar" 0)))
 TeX-dialect)

(defvar LaTeX-lipsum-package-options
  '("nopar")
  "Package options for the lipsum package.")

;; lipsum.el ends here
