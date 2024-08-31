(define-package "git-commit" "20240830.2117" "Edit Git commit messages"
  '((emacs "26.1")
    (compat "30.0.0.0")
    (seq "2.24")
    (transient "0.7.4")
    (with-editor "3.4.1"))
  :commit "fbcd6d67a637f03f8b48291fa7fe2c78488ca9d3" :authors
  '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
    ("Sebastian Wiesner" . "lunaryorn@gmail.com")
    ("Florian Ragwitz" . "rafl@debian.org")
    ("Marius Vollmer" . "marius.vollmer@gmail.com"))
  :maintainers
  '(("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev"))
  :maintainer
  '("Jonas Bernoulli" . "emacs.magit@jonas.bernoulli.dev")
  :keywords
  '("git" "tools" "vc")
  :url "https://github.com/magit/magit")
;; Local Variables:
;; no-byte-compile: t
;; End:
