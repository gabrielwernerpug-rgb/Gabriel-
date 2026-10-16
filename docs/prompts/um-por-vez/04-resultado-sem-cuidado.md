Um problema só: **a tela de resultado desenha cartões vazios** quando a planta não tem plano de cuidado.

Quando a planta vem do GBIF/Wikipédia (`careAvailable: false`), o `ResultBody` desenha todos os cartões vazios. O tipo `Plant` do frontend nem tem `careAvailable`, `summary`, `sourceLabel` ou `sourceUrl`, então essas informações somem.

Faça:

1. Acrescente ao tipo `Plant` (em `plants.ts`), todos opcionais: `careAvailable`, `summary`, `sourceLabel`, `sourceUrl` e `taxonomy`.
2. Se `careAvailable === false`:
   - não desenhe os cartões de cuidado;
   - mostre "Identificamos a espécie, mas ainda não temos um plano de cuidado confiável para ela", o `summary`, o link da fonte e o botão **Tentar gerar o plano de cuidado**;
   - o botão chama a API com `correctKey` se a planta estiver no catálogo.
3. **Sempre mostre a procedência** no resultado. Exemplo: "Identificado por Pl@ntNet · Cuidados escritos por IA".
4. Aviso discreto no fim do resultado: "Identificação e cuidados gerados por IA. Em caso de dúvida, consulte um agrônomo ou viveirista."

No fim: build limpo e o que mudou.
