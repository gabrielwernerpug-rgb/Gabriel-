# Fases 5 a 7: funcionalidades novas

As Fases 1 a 4 deixam o app **correto e publicável**. Estas três trazem o que
você pediu e que ainda não existe. Mande **uma por vez**, só depois da Fase 4.

O detalhamento de cada uma está em
[`../ANALISE-COMPLETA.md`](../ANALISE-COMPLETA.md), seções F1 a F4 e E3.

---

## Fase 5: Minhas plantas

```
Fase 5: "Minhas plantas". Pré-requisito: Fase 4 aplicada, incluindo o bucket plant-photos.

Hoje a planta identificada só existe na memória da tela. Crie:

1. Tabela user_plants: id, user_id (FK auth.users ON DELETE CASCADE), catalog_key,
   sci, name, nickname, photo_path, room, created_at. RLS por auth.uid() nas 4 operações.
   Limite de 50 plantas por usuário.
2. No resultado, botão "Salvar em Minhas plantas". Para o Pro, salvar automaticamente.
3. Na barra de baixo, aba "Minhas plantas": grade com a foto da pessoa e o apelido.
   Cada planta abre com o plano de cuidado, o chat, os lembretes dela e os botões
   "Renomear" e "Remover".
4. Chat e lembretes passam a apontar para user_plant_id (coluna nova, opcional, para
   não quebrar os antigos). Duas samambaias são duas plantas.

Build limpo e o teste de cada item.
```

---

## Fase 6: planta doente e diário

```
Fase 6: diagnóstico de planta doente e diário com foto. Pré-requisito: Fase 5 aplicada.

1. DIAGNÓSTICO. Botão na home "Minha planta está doente", ao lado de "Identificar planta".
   - Endpoint /api/diagnose-plant, cota própria kind='diagnose': Pro 10 por dia, grátis 1 por mês.
     Passa pelo geminiGate e pelo logAiCall.
   - Fluxo: identifica a espécie (reaproveita o fluxo atual) → Gemini com a foto + a espécie
     → JSON validado com zod:
     { saudavel, problemas: [{ nome, confianca, sinais_na_foto, causa, o_que_fazer_hoje[],
       o_que_fazer_na_semana[], gravidade: leve|moderada|grave }], perguntas[] }
   - Mostre as "perguntas" e deixe a pessoa responder para refinar. É mais 1 chamada,
     sem cobrar outra cota.
   - Gravidade "grave" → "Procure um viveirista ou agrônomo" em destaque.
   - Defensivo químico sempre com o aviso de receituário.

2. DIÁRIO. Dentro de cada planta de "Minhas plantas", botão "Foto de hoje".
   - Tabela plant_journal: id, user_plant_id, user_id, photo_path, note, ai_summary,
     health_score (0-100), created_at. RLS por auth.uid().
   - Pro: a IA compara com a foto anterior ("surgiram folhas novas", "o amarelado aumentou").
     No máximo 1 análise por planta por dia. Grátis: guarda a foto, sem análise.
   - Linha do tempo com as fotos e um gráfico simples de saúde.
   - Lembrete opcional "Hora da foto da sua <apelido> 📸", pelo mesmo sistema de push.

Build limpo e o teste de cada item.
```

---

## Fase 7: cobrança e chat com fontes

```
Fase 7: assinatura Pro e chat que consulta fontes. Pré-requisito: Fase 6 aplicada.

1. STRIPE (o conector já está ligado no workspace).
   - Produto "Smart Garden Pro", mensal. O preço eu informo depois de ver o custo real
     em ai_calls. Deixe configurável.
   - Botão "Assinar Pro" em /conta e nos cartões Pro → Checkout.
   - Webhook /api/public/stripe-webhook COM verificação de assinatura. Atualiza
     profiles.plan, subscription_status ('active', 'past_due' ou 'canceled') e
     stripe_customer_id. user_plan() já trata 'active'.
   - Portal do cliente para cancelar e trocar o cartão.

2. CHAT COM FONTES. Hoje o chat responde de memória e não sabe o que a tela mostrou.
   - O cliente deixa de mandar plantName e o histórico. Manda só o chatId.
   - O servidor busca no banco o nome, o plano de cuidado e as últimas 20 mensagens.
     Assim ninguém consegue injetar instruções nem forjar falas da IA.
   - Antes de responder, o servidor junta o plano de cuidado da planta, o resumo da
     Wikipédia e a taxonomia do GBIF, e manda como contexto: "responda com base nessas
     fontes; se não souber, diga que não sabe; seja coerente com o plano de cuidado".
   - Se o gateway de IA do Lovable aceitar busca do Google (grounding) no Gemini, use
     para perguntas fora do plano. Me diga se aceita.
   - Mostre embaixo da resposta: "Fontes: Wikipédia, GBIF".

Build limpo e o teste de cada item.
```
