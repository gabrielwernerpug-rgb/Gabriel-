Um problema só: **quem conversa muito perde as mensagens recentes ao recarregar.**

Em `garden-store.ts`, `loadChats` busca `order("created_at", { ascending: true }).limit(600)`, ou seja, as **600 mais antigas** de todas as conversas juntas.

Faça: buscar as **50 mais recentes de cada conversa** (ordem decrescente por conversa) e inverter para mostrar.

No fim: build limpo e o que mudou.
