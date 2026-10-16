Um problema só: **não existe tempo limite.** Se o servidor travar, a tela "Analisando sua planta…" gira para sempre. No servidor, o pior caminho chega a 55 s.

Faça:

1. `AbortController` de **60 s** no fetch da identificação e no do chat.
2. Na tela "Analisando sua planta…":
   - botão **Cancelar**;
   - depois de 15 s, a frase "Está demorando mais que o normal…".
3. Estouro de tempo → "A análise demorou demais. Tente de novo."

No fim: build limpo e o que mudou.
