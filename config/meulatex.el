; Configurações para fazer AucTeX + RefTex:

;; Turn on RefTeX in AUCTeX
(add-hook 'LaTeX-mode-hook 'turn-on-reftex)

;; Activate nice interface between RefTeX and AUCTeX
(setq reftex-plug-into-AUCTeX t)

;; Ensina RefTeX sobre longtblr:
(with-eval-after-load 'reftex
  (add-to-list 'reftex-label-alist
               '("longtblr"       ; Nome do ambiente
                 ?t               ; Tipo (t = table, f = figure, e = equation)
                 "tab:"           ; Prefixo sugerido
                 "~\\ref{%s}"     ; Formato da referência (com espaço não separável)
                 nil              ; Não usar contador especial
                 (regexp "[Cc]aption\\|label") ; Contexto para buscar
                 )))
