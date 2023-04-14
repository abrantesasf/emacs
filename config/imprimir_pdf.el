;;----------------------------------------------------------;;
;; Imprime um buffer em PDF (C-c p)
;;----------------------------------------------------------;;
;; Retirado de: internet, mas não lembro de onde :^(

(defun print-to-pdf ()
  (interactive)
  (ps-spool-buffer-with-faces)
  (setq nome-arquivo (buffer-file-name))
  (switch-to-buffer "*PostScript*")
  (setq nome-arquivo-ps (concat nome-arquivo ".ps"))
  (write-file nome-arquivo-ps)
  (kill-buffer (buffer-name))
  (setq pdf-target-name (concat nome-arquivo ".pdf"))
  (setq cmd (concat "ps2pdf14 " nome-arquivo-ps " \"" pdf-target-name "\""))
  (shell-command cmd)
  (setq cmd (concat "rm " nome-arquivo-ps))
  (shell-command cmd)
  (message (concat "Arquivo gravado em: " pdf-target-name)))

(global-set-key (kbd "C-c p") 'print-to-pdf)

