# Arquitetura

Documenta a implementação do **Lovable** (`bloom-brighten-build`), que é a mais atual.
A implementação do Emergent está descrita no final, para referência.

## Stack

TanStack Start + TypeScript, com Supabase para autenticação e persistência, shadcn/ui para
os componentes e Tailwind para o estilo. O build usa Bun.

## Mapa dos arquivos que importam

```
src/
  components/smart-garden/
    SmartGarden.tsx        # a tela inteira do app
    plants.ts              # catálogo offline de 8 plantas (tipos + dados)
    smart-garden.css       # estilo específico da tela
  routes/
    __root.tsx             # shell HTML, <head>, error boundary, 404
    index.tsx              # rota principal
    api/identify-plant.ts  # POST — identificação por foto
    api/chat-plant.ts      # POST — chat por planta
  lib/
    api-guard.ts           # allowlist de origem, IP do cliente, rate limit
    garden-store.ts        # leitura/escrita no Supabase
  integrations/supabase/   # clientes (browser e server) e tipos
supabase/migrations/       # schema versionado
```

## Endpoints

Ambos são **same-origin**: nenhum cabeçalho `Access-Control-Allow-Origin` é enviado, e o
`Origin` é validado contra uma allowlist explícita (`isAllowedOrigin`) em vez de comparado
com o `Host` — o `Host` visto pelo servidor está atrás de proxy/CDN e não é confiável.

### `POST /api/identify-plant`

Recebe `{ image }` (data URL ou base64 puro) e devolve `{ plant, confidence }`.

- Rate limit: **10 requisições / 60s por IP**.
- Modelo: `google/gemini-2.5-flash` via `ai.gateway.lovable.dev`, com
  `response_format: json_object`.
- O prompt exige um JSON de formato rígido: 3 itens em `where`, exatamente 5 nutrientes,
  5 passos e 4 problemas.
- **Corte de confiança:** abaixo de `0.5` o endpoint devolve `plant: null`. A instrução
  "nunca invente" no prompt é reforçada aqui no código, não confiada só ao modelo.
- Erros do gateway são traduzidos: `429` → rate limited, `402` → créditos de IA esgotados,
  qualquer outro → `502`.

### `POST /api/chat-plant`

Recebe `{ plantName, plantSci, messages }` e devolve `{ reply }`.

- Rate limit: **20 requisições / 60s por IP**.
- Validação de entrada: no máximo 20 mensagens por requisição, 2000 caracteres por
  mensagem, `role` restrito a `user`/`assistant`, e `plantName`/`plantSci` truncados em
  120 caracteres.
- O system prompt restringe o assunto a jardinagem e proíbe HTML e markdown na resposta.
  A resposta ainda passa por `.replace(/<[^>]*>/g, "")` no servidor — a instrução ao
  modelo não é tratada como garantia.

## Rate limiting

`rateLimit()` em `src/lib/api-guard.ts` chama a função `rate_limit_hit` no Postgres via
`supabaseAdmin.rpc`. Por ser feito no banco e não em memória, o limite **sobrevive a
redeploy e vale para todas as instâncias em paralelo** — o que um contador em memória por
processo não garantiria.

**Decisão consciente:** se a chamada ao banco falhar, a função registra o erro e devolve
`{ ok: true }`, ou seja, **falha liberando o acesso**. A disponibilidade do app foi
priorizada sobre a rigidez do limite. Vale reavaliar caso o custo de IA vire problema.

## Banco de dados

Três tabelas, todas com Row Level Security ligada e políticas por operação
(`SELECT`/`INSERT`/`UPDATE`/`DELETE`), todas checando `auth.uid() = user_id`:

| Tabela | Conteúdo | Observações |
|---|---|---|
| `plant_chats` | uma conversa por planta | `UNIQUE (user_id, plant_key)`; trigger mantém `updated_at` |
| `plant_messages` | mensagens da conversa | FK com `ON DELETE CASCADE`; índice em `chat_id` |
| `reminders` | lembretes de rega | frequência, horário, quantidade, ativo/inativo |

`user_id` tem `DEFAULT auth.uid()`, então o dono é preenchido pelo banco e não pelo
cliente. O acesso é concedido a `authenticated` e `service_role` — não a `anon`.

## Sessão e imagens

`ensureSession()` faz login anônimo no Supabase (`signInAnonymously`) quando não há sessão,
para que o usuário use o app sem criar conta e ainda assim tenha os dados protegidos por RLS.

As fotos enviadas pelo usuário são data URLs base64 e **não são gravadas no banco**:
`sanitizePlantForDb()` troca qualquer `data:` por uma imagem padrão do Unsplash. A escolha
evita inchar o Postgres com megabytes de base64, mas tem um efeito visível — ao recarregar,
a planta do usuário volta com a foto genérica. Ver `docs/AUDIT.md`.

## Implementação do Emergent (`smart-plant-doc`)

FastAPI + MongoDB + React, com um conjunto de funcionalidades **diferente** do Lovable:

- Login com Google (sessão por cookie), em vez de sessão anônima.
- Painel `/admin` protegido no backend por `Depends(require_admin)` — a checagem é na API
  e devolve `403`, não apenas um redirecionamento de tela.
- Cota de IA de 20 análises/dia por usuário, persistida na collection `ai_usage` com
  `_id = "{user_id}:{YYYY-MM-DD}"` e `$inc` atômico com upsert, e rollback do contador
  quando a análise falha.
- Diário da planta, lembretes e link público de compartilhamento, com token
  `secrets.token_urlsafe(16)`.

**Estado:** pausada por créditos esgotados. A última iteração aplicou correções que **nunca
foram verificadas** — o testing agent foi interrompido antes de rodar. Ver `docs/AUDIT.md`.
