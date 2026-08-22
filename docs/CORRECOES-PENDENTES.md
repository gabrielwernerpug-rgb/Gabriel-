# Checklist antes de publicar

Estado em **22/08**.

---

## 🔴 Falta ligar a Lovable AI no workspace

O gateway responde `403 — Lovable AI is disabled for this workspace`. Sem isso a
identificação por foto não funciona pela fonte principal.

**Ação:** ativar a Lovable AI em **Connectors**, no projeto do Lovable.

> Desde a cascata de fontes (commit `99638022`), o app não fica mais mudo quando
> isso acontece: cai para GBIF + Wikipédia e ainda identifica a espécie. Mas sem
> a IA **não há plano de cuidado**, que é o produto. Continua sendo bloqueio.

---

## 🟠 Três lacunas da última rodada

Pedidas e não entregues no commit `99638022`. A mensagem com estas correções não
chegou a ser enviada — os créditos do Lovable acabaram.

### 1. `chat-plant` continua sem cota por usuário

`src/routes/api/chat-plant.ts` só tem `rateLimit('chat-plant:' + clientIp(...))`
— 20 por minuto por IP. Não chama `userIdFromRequest`, `aiQuotaHit` nem
`aiQuotaRefund`.

Como o chat também chama o Gemini, dá para queimar crédito de API por ali sem
esbarrar em cota nenhuma — exatamente o buraco que a cota do `identify-plant`
fechou.

**Ação:** aplicar o mesmo padrão de `identify-plant.ts` — validar token, consumir
cota por usuário, e devolver a cota em **todos** os caminhos de erro (gateway
inalcançável, 402, 429, 502, resposta vazia).

### 2. As 8 plantas não foram semeadas em `plant_catalog`

A migration `20260822173709` cria a tabela mas **não tem nenhum INSERT**, e não
há seed no código. Se a home passou a ler do banco, está mostrando catálogo
vazio.

**Ação:** semear as 8 de `plants.ts` com `source = 'seed'` — valor que o
`saveToCatalog` já trata como "tem plano de cuidado" e protege de ser
sobrescrito por uma fonte sem plano.

**Cuidado:** orquídea, palmeira e lavanda usam `img` vindo de import do bundler,
não URL. Gravar assim deixa as três sem imagem ao ler do banco.

### 3. A tela "Todas as plantas" não existe

Não há arquivo de rota novo em `src/routes/`.

**Ação:** listar tudo que o site conhece, com busca por nome popular e
científico, procedência de cada uma, e marcação visual das que estão sem plano
de cuidado completo.

---

## ✅ Resolvido

### Cascata de fontes + catálogo persistente (`99638022`)

`src/lib/plant-sources.ts`, com a ordem: **IA (Gemini)** → **Pl@ntNet** (pulada
sem quebrar se não houver `PLANTNET_API_KEY`) → **GBIF + Wikipédia** (gratuitas,
sem chave, com fallback pt → en).

A regra crítica foi respeitada: `careUnavailablePlant()` devolve rega,
nutrientes, solo, passos e problemas **vazios**, com `careAvailable: false` e a
procedência (`source`, `sourceLabel`, `sourceUrl`). Nada de plano de cuidado
inventado a partir de fonte que não sabe — instrução de rega errada mata a
planta de quem usa.

O agente ainda acrescentou por conta própria uma proteção que não foi pedida e
estava certa: `saveToCatalog` **não sobrescreve** um registro que tem plano de
cuidado por um que não tem.

Tabela `plant_catalog` com índice único em `lower(sci)` (sem espécie duplicada),
leitura pública e **nenhuma policy de escrita** — usuário não grava no catálogo.

### Cron do push autenticado (`32fa1db4` + 17/08)

Segredo em `app_config` gravado por parâmetro, job reagendado com
`x-cron-secret`, validação de que existe exatamente 1 job, e `REVOKE ALL ON
app_config FROM anon, authenticated`.

### Sessão válida antes das rotas protegidas (17/08)

`validSession()` checa expiração com folga de 60s, renova com `refreshSession()`
e só cai no login anônimo em último caso. Verificado com teste em aba limpa: sem
401.

### Emergent — iteração 3 finalmente verificada (22/08)

O testing agent, que vinha sendo cortado desde 09/08, **rodou até o fim**:

- Suíte completa em paralelo: **48/50**
- Os 2 que falharam eram colisão da própria infra de teste — dois workers `xdist`
  batendo em `/api/plants/analyze` ao mesmo tempo, ou seja, o rate limit fazendo
  o trabalho dele
- Re-execução serial de `test_iter3_features.py`: **6/6**
- Relatório em `/app/test_reports/iteration_3.json`

Ficaram verificados: correção do login (race condition no `AuthCallback`), rate
limit de 20/dia no Mongo com rollback quando a análise falha, tokens visuais, e
regressão de identificação, chat, diário, lembretes, share e admin.

Os créditos do Emergent acabaram logo depois, antes do catálogo persistente e da
cascata GBIF/Wikipédia daquele lado.

---

## Efeitos colaterais conhecidos (não bloqueiam)

- **Sessão anônima perdida = histórico perdido.** Se o refresh token expirar,
  cria-se uma sessão anônima nova e conversas e lembretes antigos ficam
  inalcançáveis. Não há alternativa melhor (conta anônima não tem credencial de
  recuperação), mas hoje acontece em silêncio — o ideal seria avisar.
- **A foto do usuário ainda some no reload** — P1 do [roadmap](ROADMAP.md).
  Precisa de Supabase Storage.
