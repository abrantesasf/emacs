;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "magit" "20260322.1930"
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
  :commit "7b79fd0aeb26d673408ec1ddc80222124cc67e95"
  :revdesc "7b79fd0aeb26"
  :keywords '("git" "tools" "vc")
  :authors '(("Marius Vollmer" . "marius.vollmer@gmail.com")
             ("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
                 ("Kyle Meyer" . "kyle@kyleam.com")))
