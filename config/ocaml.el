;;-*- lexical-binding: t; -*-
;;----------------------------------------------------------;;
;; Configuração para o OCaml:
;;----------------------------------------------------------;;
;; Usa o ocp-indent instalado pelo opam (switch "default"):
;;    opam install ocp-indent

(let ((ocaml-site-lisp (expand-file-name "~/.opam/default/share/emacs/site-lisp")))
  (if (file-directory-p ocaml-site-lisp)
      (progn
        (add-to-list 'load-path ocaml-site-lisp)
        (require 'ocp-indent))
    (message "OCaml: diretório %s não encontrado (o opam está instalado?)"
             ocaml-site-lisp)))
