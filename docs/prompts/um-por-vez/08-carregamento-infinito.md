**Antes de tudo, confira o 07 no navegador**, que você não chegou a ver:
- abra `/plantas`, toque numa planta e veja se abre o resultado com "Do catálogo";
- busque "rosa, vermelha" e veja se não quebra;
- veja se a lista de correção não tem coluna vazia.

Se algo estiver errado, corrija.

Depois, **um problema só: não existe tempo limite.** Se o servidor travar, a tela "Analisando sua planta…" gira para sempre. No servidor, o pior caminho chega a ~55 s: Pl@ntNet 15 s + Gemini com foto 20 s + plano de cuidado 20 s, com até uma nova tentativa.

Faça, **sem mudar o banco**:

1. `AbortController` de **60 s** em todos os fetch do frontend que chamam `/api/identify-plant` (foto, escolha de candidata, correção e "Tentar gerar o plano de cuidado") e `/api/chat-plant`.
2. Na tela "Analisando sua planta…":
   - botão **Cancelar**, que aborta o fetch e volta para a home sem mensagem de erro;
   - depois de **15 s**, troque o subtítulo para "Está demorando mais que o normal…".
3. Estouro de tempo → mensagem "A análise demorou demais. Tente de novo." No chat: "A resposta demorou demais. Tente de novo."
4. Cancelar ou estourar o tempo não pode deixar o estado preso: `analyzing`, `chatPending`, `generatingCare` e as refs de "ocupado" voltam a `false`.

No fim: build limpo, testes e o que mudou.
