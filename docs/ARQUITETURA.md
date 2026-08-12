# Arquitetura

Duas implementações independentes do mesmo produto, construídas em plataformas
diferentes. Este documento registra como cada uma funciona, para que a decisão de
qual manter (ou como fundir) seja tomada com base em fatos.

---

## Lovable — "Bloom Booster"

**Stack:** TanStack Start (SSR) + TypeScript + Tailwind + shadcn/ui
**Banco:** Supabase (Postgres)
**Projeto:** `ae9ae530-ced6-41c2-a9d9-8f939661629d`

### Estrutura

```
src/components/smart-garden/
  SmartGarden.tsx      Componente principal (toda a UI)
  plants.ts            Catálogo local de 8 plantas
  smart-garden.css     Estilos do módulo
src/routes/api/
  identify-plant.ts    POST — identificação por foto
  chat-plant.ts        POST — chat sobre a planta
src/lib/
  garden-store.ts      Camada de acesso ao Supabase
  api-guard.ts         Rate limit + checagem de origem
```

### Catálogo de plantas (`plants.ts`)

8 espécies pré-carregadas, cada uma com um objeto `Plant` completo:

```ts
type Plant = {
  name: string; sci: string; img: string; thumb: string; conf: string;
  water: { freq: string; amount: string; best: string };
  where: { title: string; desc: string }[];   // 3 itens — onde regar
  nuts:  { n: string; v: number; c: 'nhi'|'nmd'|'nlo'; t: string; ex: string }[]; // 5
  soil:  Record<string, string>;
  steps: string[];                             // 5 passos de plantio
  tip: string;
  problems: { icon: string; title: string; sev: 'danger'|'warn';
              sev_label: string; cause: string; fix: string }[];  // 4
};
```

O mesmo formato é exigido do LLM na identificação por foto — ou seja, planta do
catálogo e planta identificada por IA são renderizadas pelo mesmo componente.

### Identificação por foto

`POST /api/identify-plant` com `{ image: <base64 ou data URL> }`.

1. Rejeita origem cruzada (`isAllowedOrigin`) — retorna 403.
2. Rate limit de **10 req/min por IP** (`api-guard.ts`) — retorna 429 com `Retry-After`.
3. Chama `google/gemini-2.5-flash` no AI Gateway da Lovable, com
   `response_format: json_object` e um prompt que fixa o schema acima.
4. Se `confidence < 0.5`, devolve `{ plant: null, confidence }` — o app mostra
   "não consegui identificar" em vez de inventar.

Resposta: `{ plant: Plant | null, confidence: number }`.

### Modelo de dados (Supabase)

Três tabelas, todas com **RLS habilitada** e políticas por `auth.uid()`:

```sql
plant_chats     (id, user_id, plant_key, plant jsonb, created_at, updated_at)
                UNIQUE (user_id, plant_key)
plant_messages  (id, chat_id → plant_chats ON DELETE CASCADE, user_id,
                 role CHECK IN ('user','assistant'), content, created_at)
reminders       (id, user_id, plant_key, name, img, freq, freq_label,
                 time, amount, enabled, created_at)
```

Trigger `update_updated_at_column()` mantém `plant_chats.updated_at` — é o que
ordena a lista de conversas (mais recente primeiro).

Sessão via `supabase.auth.signInAnonymously()`: o usuário tem histórico sem
precisar criar conta.

### Push de lembretes (commit `01f5903a`)

```
public/sw.js                          Service worker
src/lib/push.ts                       Assinatura no cliente
src/routes/api/public/vapid-key.ts    Chave pública VAPID
src/routes/api/public/send-reminders.ts  Disparo (chamado pelo cron)
```

`push_subscriptions (id, user_id, endpoint UNIQUE, p256dh, auth, created_at)`,
com RLS por `auth.uid()`. `reminders` ganhou `timezone`, `last_sent_at` e
`updated_at` (com trigger), mais um índice parcial em `enabled`.

O coração é `claim_due_reminders()` — `SECURITY DEFINER`, revogada de
`anon`/`authenticated` e concedida só a `service_role`:

```sql
WITH due AS (
  SELECT r.id FROM public.reminders r
  WHERE r.enabled
    AND (now() AT TIME ZONE COALESCE(NULLIF(r.timezone,''),'UTC'))::time >= (r.time || ':00')::time
    AND (r.last_sent_at IS NULL OR (...date diff...) >= GREATEST(1, ...freq...))
  FOR UPDATE SKIP LOCKED
)
UPDATE public.reminders AS t SET last_sent_at = now()
WHERE t.id IN (SELECT due.id FROM due)
RETURNING t.id, t.user_id, t.name, t.amount, t.plant_key;
```

Seleciona e marca na **mesma** operação, com `FOR UPDATE SKIP LOCKED` — duas
execuções simultâneas do cron não mandam a notificação repetida. Quando o
endpoint de push responde 404 ou 410, a assinatura morreu e a linha é apagada.

Agendamento: `pg_cron` a cada 5 minutos, via `net.http_post`.

> ⚠️ **O endpoint de disparo está aberto.** Sem autenticação, rodando com service
> role, e aceitando GET. É o P0 do roadmap e bloqueia a publicação.

### Limitação conhecida: fotos do usuário não persistem

`garden-store.ts` remove data URLs base64 antes de gravar (`sanitizePlantForDb`),
trocando por uma imagem de fallback do Unsplash:

```ts
export const FALLBACK_IMG = "https://images.unsplash.com/photo-1466692476868-...";
const stripDataUrl = (v) => !v || v.startsWith("data:") ? FALLBACK_IMG : v;
```

A decisão evita gravar megabytes de base64 no Postgres — correta. Mas o efeito
é que **ao recarregar, a foto que o usuário tirou some** e a planta volta com
uma imagem genérica. A solução certa é Supabase Storage: subir o arquivo, gravar
só a URL. Está no roadmap como prioridade 1.

---

## Emergent — "smart-plant-doc"

**Stack:** FastAPI (Python) + MongoDB + React
**Job:** `d8b2d3bb-699d-4031-b777-4d841b3cc0e9`

Implementação mais completa em funcionalidade. Tem tudo que o Lovable tem, mais:

- **Diário da planta** — registro de evolução ao longo do tempo
- **Link de compartilhar** — token gerado com `secrets.token_urlsafe(16)` (128 bits)
- **Painel `/admin`** — protegido por `Depends(require_admin)` no backend, não só
  por redirecionamento de tela; usuário comum recebe **403** direto da API
- **Rate limit persistente** — 20 identificações/dia por usuário, na collection
  `ai_usage` com `_id = "{user_id}:{YYYY-MM-DD}"`, `$inc` atômico + upsert.
  Sobrevive a redeploy e vale para todas as instâncias em paralelo. Admin isento.
  Endpoint `GET /api/ai/quota` expõe o saldo do dia.

### Correção de login (iteração 3)

Havia uma race condition no `AuthCallback`: depois de `setUser(data)` e
`navigate("/dashboard")`, o `ProtectedRoute` renderizava antes do state propagar
e jogava o usuário de volta para `/`. Corrigido trocando por
`window.location.replace("/dashboard")` — o reload completo garante que o
`AuthProvider` refaça `/auth/me` já com o cookie novo.

### Emergent — bloqueado

O trabalho parou em **09/08/2026** com `credits_exhausted: true`.

O que ficou pendente: o **testing agent foi cortado antes de rodar**. As três
mudanças da iteração 3 (correção do login, rate limit no Mongo com rollback do
contador quando a análise falha, e os tokens visuais) estão **implementadas mas
não verificadas de ponta a ponta**, e não houve teste de regressão em
identificação, chat, diário, lembretes, share e admin.

**Para destravar:** recarregar créditos no Emergent e rodar o testing agent até
o fim. Nada de código precisa ser reescrito antes disso.

---

## Design tokens (compartilhados)

Validados no Lovable e portados para o Emergent na iteração 3:

```css
:root{
  --ink-900:#0d1117; --ink-700:#57606a; --ink-500:#8c959f;
  --ink-200:#d0d7de; --ink-100:#eaeef2;
  --bg:#ffffff; --bg-2:#f6f8fa; --bg-3:#eef1f4;
  --green:#22c37a; --green-dark:#159958; --green-100:#e3f8ee;
  --radius-sm:10px; --radius-md:16px; --radius-lg:24px; --radius-full:999px;
  --shadow-sm:0 1px 2px rgba(13,17,23,.06);
  --shadow-md:0 10px 30px rgba(13,17,23,.12);
}
@media (prefers-color-scheme: dark){
  :root{
    --ink-900:#f0f3f6; --ink-700:#b6bec6;
    --bg:#0d1117; --bg-2:#161b22; --bg-3:#1c2128;
    --ink-100:#1c2128; --ink-200:#2a3138;
  }
}
```

- Fonte **Inter** em tudo
- Botão primário: gradiente `--green` → `--green-dark`, `--radius-md`, elevação
  no hover, `scale(.96)` no clique
- Cards: fundo `--bg-3`, `--radius-md`, `--shadow-sm` só no hover
- Bolha de chat do usuário: gradiente verde, cantos arredondados exceto o
  inferior direito
- Loading: 3 pontinhos verdes com bounce (não spinner)
- Dark mode automático via `prefers-color-scheme`, sem toggle manual
