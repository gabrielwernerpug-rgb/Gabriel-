Um problema só: **"Todas as plantas" mostra as plantas, mas não dá para abrir nenhuma.** E "Não é essa planta?" é um beco sem saída.

Faça:

1. Em `plantas.tsx`, **cada card abre a planta**, na mesma tela de resultado.
2. **Busca robusta** em `catalog.ts`: antes de montar o `.or(...)`, tire do termo vírgula, parênteses, ponto e `%`. Hoje "rosa, vermelha" quebra a consulta e aparece "Nada encontrado".
3. **Paginação:** botão "Carregar mais" de 50 em 50, no lugar do limite fixo de 200.
4. **"Não é essa planta?"** sem resultado na busca mostra:
   - **Tentar com outra foto**, com a dica "Fotografe a flor ou o fruto, de perto e com boa luz". Volta para a home com o seletor já em "Flor";
   - **Cancelar**.
5. Acrescente **"Casca/tronco"** (`bark`) ao seletor "O que está na foto?". O servidor já aceita.

No fim: build limpo e o que mudou.
