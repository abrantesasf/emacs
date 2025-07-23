(defun atualizar-data-no-buffer ()
  "Procura uma linha com o padrão '* Date    : YYYY-MM-DD HH:MM -0300'
e substitui a data e hora pela data e hora atual do sistema."
  (interactive)
  (let ((pattern "^\\* Date[ \t]+: [0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\} [0-9]\\{2\\}:[0-9]\\{2\\} [-+]\\?[0-9]\\{4\\}")
        (nova-data (format-time-string "* Date    : %Y-%m-%d %H:%M %z")))
    (save-excursion
      (goto-char (point-min))
      (when (re-search-forward pattern nil t)
        (replace-match nova-data)))))

;; Opcional: você pode adicionar um atalho, por exemplo C-c d
(global-set-key (kbd "C-c d") 'atualizar-data-no-buffer)
