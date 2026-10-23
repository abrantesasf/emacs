;;-*- lexical-binding: t; -*-
;;--------------------------------------------------------------------------- ;;
;; Atualiza cabeçalho padronizado de data (basicamente para os meus códigos
;; de programas em C).
;;--------------------------------------------------------------------------- ;;

;; Modo de funcionamento:
;;   a) Procura pela primeira linha com um dos formatos:
;;      " * Date : 2025-04-21 14:12 -0300"
;;      " * Data : 2025-04-21 14:12 -0300"
;;   b) Troca o que vem depois dos dois-pontos pela data, hora e timezone
;;      atuais, mantendo o alinhamento original da linha.
(defun atualizar-data-cabecalho ()
  "Procura por uma linha de data no formato `* Date :' ou `* Data :' e a atualiza.
É flexível quanto ao espaçamento no início da linha e ao redor dos elementos."
  (interactive)
  (save-excursion
    ;; Começa a buscar em point-min (início do buffer):
    (goto-char (point-min))
    ;; Expressão regular de busca:
    (if (re-search-forward "^[ \t]*\\*[ \t]+Dat[ae][ \t]*:" nil t)
        ;; Se encontrou, executa a substituição
        (progn
          ;; Apaga o que vem depois dos dois-pontos (sem usar o kill-ring)
          (delete-region (point) (line-end-position))
          ;; Insere a data atual
          (insert " " (format-time-string "%Y-%m-%d %H:%M %z")))
      ;; Se NÃO encontrou, exibe uma mensagem
      (message "A linha de Data não foi encontrada!"))))

;; Associa a função 'atualizar-data-cabecalho' ao atalho de teclado C-c d
(global-set-key (kbd "C-c d") 'atualizar-data-cabecalho)
