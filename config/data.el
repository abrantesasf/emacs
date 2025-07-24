;;--------------------------------------------------------------------------- ;;
;; Atualiza cabeçalho padronizado de data (basicamente para os meus códigos
;; de programas em C).
;;--------------------------------------------------------------------------- ;;

;; Modo de funcionamento:
;;   a) Procura por texto com o formato:
;;      " * Date : 2025-04-21 14:12 -0300"
;;   b) Troca a data, hora e timezone pelos valores atuais.
(defun atualizar-data-cabecalho ()
  "Procura por uma linha de data no formato '* Date ...' e a atualiza.
  É flexível quanto ao espaçamento no início da linha e ao redor dos elementos."
  (interactive)
  (save-excursion
    ;; Começa a buscar em point-min (início do buffer):
    (goto-char (point-min)) 
    ;; Expressão regular de busca:
    (if (re-search-forward "^\\s-*\\(\\*\\s-+Date\\s-*:\\s-+\\)" nil t)
        ;; Se encontrou, executa a substituição
        (progn
          ; Vai para o início da linha
          (goto-char (match-beginning 0))
          ; Apaga a linha inteira
          (kill-line)
          ;; Insere a nova linha com a data atual e formatação padronizada
          (insert (format " * Date    : %s"
                          (format-time-string "%Y-%m-%d %H:%M %z"))))
      ;; Se NÃO encontrou, exibe uma mensagem
      (message "A linha de Data não foi encontrada!"))))

;; Associa a função 'atualizar-data-cabecalho' ao atalho de teclado C-c d
(global-set-key (kbd "C-c d") 'atualizar-data-cabecalho)
