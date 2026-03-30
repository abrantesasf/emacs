;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "magit" "20260329.2122"
  "A Git porcelain inside Emacs."
  '((emacs         "28.1")
    (compat        "30.1")
    (cond-let      "0.2")
    (llama         "1.0")
    (magit-section "4.5")
    (seq           "2.24")
    (transient     "0.12")
    (with-editor   "3.4"))
  :url "https://github.com/magit/magit"
  :commit "6c7d3c34b51383f32f6a7a84fb1472e4f5ab7cf2"
  :revdesc "6c7d3c34b513"
  :keywords '("git" "tools" "vc")
  :authors '(("Marius Vollmer" . "marius.vollmer@gmail.com")
             ("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
                 ("Kyle Meyer" . "kyle@kyleam.com")))
