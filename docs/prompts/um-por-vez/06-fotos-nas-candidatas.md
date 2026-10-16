Um problema só: **quando a confiança vem baixa, a pessoa escolhe entre 3 nomes científicos que ela não conhece.** Com uma foto de exemplo ao lado de cada nome, ela acerta muito mais.

Faça:

1. **Pl@ntNet:** em `identifyCandidatesWithPlantNet`, acrescente `include-related-images=true` à chamada. Para cada resultado, guarde uma imagem pequena (`images[0].url.m` ou `.s`), o autor e a licença, junto da candidata.
2. **Candidatas do Gemini:** use a miniatura do `wikipediaSummary` da espécie, se houver.
3. Essas imagens vão junto em `identify_sessions.candidates` e na resposta.
4. **Na tela:** foto pequena ao lado de cada candidata. Embaixo da lista, o crédito: "Fotos de referência: Pl@ntNet (CC BY-SA)".
5. Registre no log do servidor quantas identificações do Pl@ntNet restam no dia (campo `remainingIdentificationRequests`; confira o nome no retorno real).

No fim: build limpo e o que mudou.
