;;; exercise.el --- AUCTeX style for `exercise.sty'  -*- lexical-binding: t; -*-

;; Copyright (C) 2014, 2020 Free Software Foundation, Inc.

;; Author: Nicolas Richard <theonewiththeevillook@yahoo.fr>
;; Created: 2014-03-17
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

;; This file adds support for `exercise.sty'.

;;; Code:

(require 'tex)
(require 'latex)

(TeX-add-style-hook
 "exercise"
 (lambda ()
   (LaTeX-add-environments
    '("Exercise")
    '("Exercise*")
    '("Answer")
    '("ExerciseList")
    )
   (TeX-add-symbols
    '("Exercise")
    '("Exercise*")
    '("Answer")
    '("ExePart")
    '("ExePart*")
    '("Question")
    '("subQuestion")
    '("ExeText")
    '("ExerciseSelect")
    '("ExerciseStopSelect")
    '("refAnswer")
    '("marker")
    '("DifficultyMarker")
    '("listofexercises")
    '("ListOfExerciseInToc")
    '("ExerciseLevelInToc")))
 TeX-dialect)

(defvar LaTeX-exercise-package-options '("noexercise" "noanswer" "exerciseonly" "answeronly" "nothing" "answerdelayed" "exercisedelayed" "lastexercise")
  "Package options for the exercise package.")

;;; exercise.el ends here
