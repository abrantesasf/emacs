;;----------------------------------------------------------;;
;; Função para rodar o comando make no diretório do arquivo
;;----------------------------------------------------------;;

(defun run-make-in-file-directory ()
  "Run 'make' in the directory of the current file if a Makefile exists.
Keep the current buffer in focus and display the *compilation* buffer in the background."
  (interactive)
  (if buffer-file-name
      (let ((file-dir (file-name-directory buffer-file-name))
            (makefile-name "Makefile"))
        (if (file-exists-p (expand-file-name makefile-name file-dir))
            (let ((default-directory file-dir))
              (save-window-excursion ;; Prevent window splitting
                (compile "make")))
          (message "No Makefile found in the directory of the current file.")))
    (message "This buffer is not visiting a file.")))

;; Bind the function to a key, e.g., F5
(global-set-key (kbd "<f5>") 'run-make-in-file-directory)

