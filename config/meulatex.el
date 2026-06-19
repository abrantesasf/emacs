; Configurações para fazer AucTeX + RefTex:

;; Turn on RefTeX in AUCTeX
(add-hook 'LaTeX-mode-hook 'turn-on-reftex)

;; Activate nice interface between RefTeX and AUCTeX
(setq reftex-plug-into-AUCTeX t)

;; Desativa scan parciais:
(setq reftex-enable-partial-scans nil)
(setq reftex-guess-label-type nil)
