;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "magit" "20250808.949"
  "A Git porcelain inside Emacs."
  '((emacs         "28.1")
    (compat        "30.1")
    (llama         "1.0.0")
    (magit-section "4.3.8")
    (seq           "2.24")
    (transient     "0.9.3")
    (with-editor   "3.4.4"))
  :url "https://github.com/magit/magit"
  :commit "573ed7f90d1317d2fc26fe54fe4a9bea64a74182"
  :revdesc "573ed7f90d13"
  :keywords '("git" "tools" "vc")
  :authors '(("Marius Vollmer" . "marius.vollmer@gmail.com")
             ("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
                 ("Kyle Meyer" . "kyle@kyleam.com")))
