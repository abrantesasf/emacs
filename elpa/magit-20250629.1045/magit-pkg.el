;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "magit" "20250629.1045"
  "A Git porcelain inside Emacs."
  '((emacs         "27.1")
    (compat        "30.1")
    (llama         "0.6.3")
    (magit-section "4.3.6")
    (seq           "2.24")
    (transient     "0.9.0")
    (with-editor   "3.4.4"))
  :url "https://github.com/magit/magit"
  :commit "10a0994ae8a3d2cd1ef5231c72f226cd71e79e68"
  :revdesc "10a0994ae8a3"
  :keywords '("git" "tools" "vc")
  :authors '(("Marius Vollmer" . "marius.vollmer@gmail.com")
             ("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
                 ("Kyle Meyer" . "kyle@kyleam.com")))
