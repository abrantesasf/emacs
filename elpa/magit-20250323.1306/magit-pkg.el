;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "magit" "20250323.1306"
  "A Git porcelain inside Emacs."
  '((emacs         "27.1")
    (compat        "30.0.2.0")
    (llama         "0.6.1")
    (magit-section "4.3.1")
    (seq           "2.24")
    (transient     "0.8.5")
    (with-editor   "3.4.3"))
  :url "https://github.com/magit/magit"
  :commit "3c0c4df461a22fa9dd2eee3831ae8e56e9f7a914"
  :revdesc "3c0c4df461a2"
  :keywords '("git" "tools" "vc")
  :authors '(("Marius Vollmer" . "marius.vollmer@gmail.com")
             ("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
                 ("Kyle Meyer" . "kyle@kyleam.com")))
