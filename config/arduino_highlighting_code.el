;; Definir palavras-chave Arduino para syntax highlighting
(font-lock-add-keywords
 'c++-mode
 '(("\\<\\(digitalWrite\\|analogRead\\|analogWrite\\|pinMode\\|delay\\|millis\\)\\>" . font-lock-keyword-face)))
