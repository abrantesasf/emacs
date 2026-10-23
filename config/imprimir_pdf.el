;;-*- lexical-binding: t; -*-
;;----------------------------------------------------------;;
;; Imprime um buffer em PDF (C-c p)
;;----------------------------------------------------------;;
;; Retirado de: internet, mas não lembro de onde :^(

(defun print-to-pdf ()
  "Imprime o buffer atual em PDF, no mesmo diretório do arquivo."
  (interactive)
  (if (not buffer-file-name)
      (message "Este buffer não está associado a um arquivo.")
    (let* ((nome-arquivo buffer-file-name)
           (nome-arquivo-ps (concat nome-arquivo ".ps"))
           (pdf-target-name (concat (file-name-sans-extension nome-arquivo) ".pdf")))
      (ps-spool-buffer-with-faces)
      (with-current-buffer "*PostScript*"
        (write-region nil nil nome-arquivo-ps))
      (kill-buffer "*PostScript*")
      (shell-command (concat "ps2pdf14 " (shell-quote-argument nome-arquivo-ps)
                             " " (shell-quote-argument pdf-target-name)))
      (delete-file nome-arquivo-ps)
      (message (concat "Arquivo gravado em: " pdf-target-name)))))

(global-set-key (kbd "C-c p") 'print-to-pdf)

