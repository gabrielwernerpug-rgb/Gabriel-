Um problema só: **quando a confiança vem baixa, a pessoa escolhe entre 3 nomes científicos que ela não conhece.** Com uma foto de exemplo ao lado de cada nome, ela acerta muito mais.

Faça, **sem mudar o esquema do banco** (`identify_sessions.candidates` já é `jsonb`, então pode guardar campos novos):

1. **Pl@ntNet:** em `identifyCandidatesWithPlantNet` (`plant-sources.ts`), acrescente `include-related-images=true` à chamada.
   - Para cada resultado, guarde uma imagem pequena (`images[0].url.s`, ou `.m` se não houver), o autor (`images[0].author`) e a licença (`images[0].license`), junto da candidata.
   - Aceite só URL `https`.
2. **Candidatas do Gemini:** use a miniatura do `wikipediaSummary` da espécie, se houver, com o crédito "Wikipédia". Busque as 3 em paralelo, com tempo limite curto (4 s cada). Se falhar, siga sem foto.
3. As imagens vão junto em `identify_sessions.candidates` e na resposta das candidatas.
4. **Na tela:**
   - foto pequena (64 px, cantos arredondados, `loading="lazy"`) ao lado de cada candidata, com o nome popular, o científico e a porcentagem;
   - sem foto, mostre o ícone de broto;
   - embaixo da lista, o crédito: "Fotos de referência: Pl@ntNet (CC BY-SA) / Wikipédia".
5. Registre no log do servidor quantas identificações do Pl@ntNet restam no dia. O campo da resposta é `remainingIdentificationRequests`; confira o nome no retorno real.

No fim: build limpo, testes e o que mudou.
