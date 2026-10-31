;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "with-editor" "20261030.2029"
  "Use the Emacsclient as $EDITOR."
  '((emacs    "28.1")
    (compat   "31.0")
    (cond-let "1.1")
    (llama    "1.0"))
  :url "https://github.com/magit/with-editor"
  :commit "91643f1d3253ec6c345f60cb8b4070db1e73f7a4"
  :revdesc "91643f1d3253"
  :keywords '("processes" "terminals")
  :authors '(("Jonas Bernoulli" . "emacs.with-editor@jonas.bernoulli.dev"))
  :maintainers '(("Jonas Bernoulli" . "emacs.with-editor@jonas.bernoulli.dev")))
