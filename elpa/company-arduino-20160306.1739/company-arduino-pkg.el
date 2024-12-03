;; -*- no-byte-compile: t; lexical-binding: nil -*-
(define-package "company-arduino" "20160306.1739"
  "Company-mode for Arduino."
  '((emacs             "24.1")
    (company           "0.8.0")
    (irony             "0.1.0")
    (cl-lib            "0.5")
    (company-irony     "0.1.0")
    (company-c-headers "20140930")
    (arduino-mode      "1.0"))
  :url "https://github.com/yuutayamada/company-arduino"
  :commit "5958b917cc5cc729dc64d74d947da5ee91c48980"
  :revdesc "5958b917cc5c"
  :keywords '("convenience" "development" "company")
  :authors '(("Yuta Yamada" . "sleepboy.zzz@gmail.com"))
  :maintainers '(("Yuta Yamada" . "sleepboy.zzz@gmail.com")))
