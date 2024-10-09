; Configurações para fazer AucTeX + RefTex:



(use-package tex
  :ensure auctex)


;; Turn on RefTeX in AUCTeX
(add-hook 'LaTeX-mode-hook 'turn-on-reftex)

;; Activate nice interface between RefTeX and AUCTeX
(setq reftex-plug-into-AUCTeX t)
