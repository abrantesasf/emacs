;; -*- mode: lisp-data; no-byte-compile: t; lexical-binding: nil -*-
(define-package "magit" "20240928.1355"
  "A Git porcelain inside Emacs."
  '((emacs         "26.1")
    (compat        "30.0.0.0")
    (dash          "2.19.1")
    (magit-section "4.1.0")
    (seq           "2.24")
    (transient     "0.7.5")
    (with-editor   "3.4.2"))
  :url "https://github.com/magit/magit"
  :commit "bf738da2deb0ab52cd9fb92353507e7fc409c093"
  :revdesc "bf738da2deb0"
  :keywords '("git" "tools" "vc")
  :authors '(("Marius Vollmer" . "marius.vollmer@gmail.com")
             ("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
                 ("Kyle Meyer" . "kyle@kyleam.com")))
