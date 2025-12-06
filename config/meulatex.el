; Configurações para fazer AucTeX + RefTex:

;; Turn on RefTeX in AUCTeX
(add-hook 'LaTeX-mode-hook 'turn-on-reftex)

;; Activate nice interface between RefTeX and AUCTeX
(setq reftex-plug-into-AUCTeX t)

;; Ensina RefTeX sobre longtblr:
(with-eval-after-load 'reftex
  ;; Diz ao RefTeX para procurar também por "label = {nome}"
  (add-to-list 'reftex-label-regexps
               "label[[:space:]]*=[[:space:]]*{\\(?1:[^}]*\\)}" t))
