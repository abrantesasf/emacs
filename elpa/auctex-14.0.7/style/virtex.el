;;; virtex.el - Common code for all TeX formats.  -*- lexical-binding: t; -*-

;; Author: Per Abrahamsen <abraham@dina.kvl.dk>
;; Maintainer: auctex-devel@gnu.org

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

;;; Code:

(require 'tex)

(TeX-add-style-hook
 "virtex"
 (lambda ()
   (TeX-add-symbols "/" "above" "abovedisplayshortskip"
                    "abovedisplayskip" "abovewithdelims" "accent"
                    "adjdemerits" "advance" "afterassignment"
                    "aftergroup" "atop" "atopwithdelims" "badness"
                    "baselineskip" "batchmode" "begingroup"
                    "belowdisplayshortskip" "belowdisplayskip"
                    "binoppenalty" "botmark" "box" "boxmaxdepth"
                    "brokenpenalty" "catcode" "char" "chardef"
                    "cleaders" "closein" "closeout" "clubpenalty"
                    "copy" "count" "countdef" "cr" "crcr" "csname"
                    "day" "deadcycles" "def" "defaulthyphenchar"
                    "defaultskewchar" "delcode" "delimiter"
                    "delimiterfactor" "delimitershortfall" "dimen"
                    "dimendef" "discretionary" "displayindent"
                    "displaylimits" "displaystyle"
                    "displaywidowpenalty" "displaywidth" "divide"
                    "doublehyphendemerits" "dp" "dump" "edef" "else"
                    "emergencystretch" "end" "endcsname" "endgroup"
                    "endinput" "endlinechar" "eqno" "errhelp"
                    "errmessage" "errorcontextlines" "errorstopmode"
                    "escapechar" "everycr" "everydisplay"
                    "everyhbox" "everyjob" "everymath" "everypar"
                    "everyvbox" "exhyphenpenalty" "expandafter"
                    "fam" "fi" "finalhyphendemerits" "firstmark"
                    "floatingpenalty" "font" "fontdimen" "fontname"
                    "futurelet" "gdef" "global" "globaldefs"
                    "halign" "hangafter" "hangindent" "hbadness"
                    "hbox" "hfil" "hfill" "hfilneg" "hfuzz"
                    "hoffset" "holdinginserts" "hrule" "hsize"
                    "hskip" "hss" "ht" "hyphenpenation" "hyphenchar"
                    "hyphenpenalty" "if" "ifcase" "ifcat" "ifdim"
                    "ifeof" "iffalse" "ifhbox" "ifinner" "ifhmode"
                    "ifmmode" "ifnum" "ifodd" "iftrue" "ifvbox"
                    "ifvoid" "ifx" "ignorespaces" "immediate"
                    "indent" "input" "inputlineno" "insert"
                    "insertpenalties" "interlinepenalty" "jobname"
                    "kern" "language" "lastbox" "lastkern"
                    "lastpenalty" "lastskip" "lccode" "leaders"
                    "left" "lefthyphenmin" "leftskip" "leqno" "let"
                    "limits" "linepenalty" "lineskip"
                    "lineskiplimit" "long" "looseness" "lower"
                    "lowercase" "mag" "markaccent" "mathbin"
                    "mathchar" "mathchardef" "mathchoise"
                    "mathclose" "mathcode" "mathinner" "mathhop"
                    "mathopen" "mathord" "mathpunct" "mathrel"
                    "mathsurround" "maxdeadcycles" "maxdepth"
                    "meaning" "medmuskip" "message" "mkern" "month"
                    "moveleft" "moveright" "mskip" "multiply"
                    "muskip" "muskipdef" "newlinechar" "noalign"
                    "noboundary" "noexpand" "noindent" "nolimits"
                    "nonscript" "nonstopmode" "nulldelimiterspace"
                    "nullfont" "number" "omit" "openin" "openout"
                    "or" "outer" "output" "outputpenalty"
                    "overfullrule" "parfillskip" "parindent"
                    "parskip" "pausing" "postdisplaypenalty"
                    "predisplaypenalty" "predisplaysize"
                    "pretolerance" "relpenalty" "rightskip"
                    "scriptspace" "showboxbreadth" "showboxdepth"
                    "smallskipamount" "spaceskip" "splitmaxdepth"
                    "splittopskip" "tabskip" "thickmuskip"
                    "thinmuskip" "time" "tolerance" "topskip"
                    "tracingcommands" "tracinglostchars"
                    "tracingmacros" "tracingonline" "tracingoutput"
                    "tracingpages" "tracingparagraphs"
                    "tracingrestores" "tracingstats" "uccode"
                    "uchyph" "underline" "unhbox" "unhcopy" "unkern"
                    "unpenalty" "unskip" "unvbox" "unvcopy"
                    "uppercase" "vadjust" "valign" "vbadness" "vbox"
                    "vcenter" "vfil" "vfill" "vfilneg" "vfuzz"
                    "voffset" "vrule" "vsize" "vskip" "vss" "vtop"
                    "wd" "widowpenalty" "write" "xdef" "xleaders"
                    "xspaceskip" "year"))
 TeX-dialect)

;;; virtex.el ends here
