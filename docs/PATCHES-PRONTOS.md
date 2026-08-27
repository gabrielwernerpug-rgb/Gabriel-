# Patches prontos para aplicar

As três lacunas da última rodada, escritas para aplicar **sem gastar crédito de
agente** — direto no editor de código do Lovable e no SQL Editor do Supabase.

Contexto do porquê em [`CORRECOES-PENDENTES.md`](CORRECOES-PENDENTES.md).

---

## 1. Cota por usuário no `chat-plant`

**Problema:** `src/routes/api/chat-plant.ts` só limita por IP. Como o chat também
chama o Gemini, dá para queimar crédito de API por ali sem esbarrar em cota
nenhuma — o mesmo buraco que a cota do `identify-plant` fechou.

**Arquivo:** `src/routes/api/chat-plant.ts`

### 1.1 — Trocar o import

```ts
// antes
import { clientIp, isAllowedOrigin, rateLimit } from "@/lib/api-guard";

// depois
import {
  aiQuotaHit,
  aiQuotaRefund,
  clientIp,
  isAllowedOrigin,
  rateLimit,
  userIdFromRequest,
} from "@/lib/api-guard";
```

### 1.2 — Adicionar o limite diário junto das outras constantes

```ts
// Chat é mais barato por chamada que a identificação, então o teto diário é
// mais generoso que os 20/dia do identify-plant.
const DAILY_USER_LIMIT = 60;
```

### 1.3 — Depois do bloco do `rateLimit` por IP, antes de ler `LOVABLE_API_KEY`

```ts
const userId = await userIdFromRequest(request);
if (!userId) {
  return json(
    { error: "unauthorized", message: "Sessão inválida. Recarregue a página e tente novamente." },
    401,
  );
}

const quota = await aiQuotaHit(userId, DAILY_USER_LIMIT);
if (!quota.ok) {
  const resets = quota.resetsAt
    ? new Date(quota.resetsAt).toLocaleString("pt-BR", { timeZone: "UTC" }) + " (UTC)"
    : "a próxima meia-noite (UTC)";
  return new Response(
    JSON.stringify({
      error: "quota_exceeded",
      message: `Você atingiu o limite de ${DAILY_USER_LIMIT} mensagens por dia. A cota reseta em ${resets}.`,
    }),
    { status: 429, headers: BASE_HEADERS },
  );
}

// Devolve a cota quando a requisição falha — erro do gateway não pode
// consumir a mensagem do usuário.
const fail = async <T>(res: T): Promise<T> => {
  await aiQuotaRefund(userId);
  return res;
};
```

### 1.4 — Envolver **todos** os retornos de erro seguintes com `fail(...)`

É o ponto que mais se erra: se sobrar um caminho de erro sem `fail`, o usuário
perde cota por um erro que não foi dele.

```ts
if (!apiKey) return fail(json({ error: "LOVABLE_API_KEY not configured" }, 500));
// … catch do request.json()      → return fail(json({ error: "Invalid JSON" }, 400));
// … !plantName                   → return fail(json({ error: "Missing 'plantName'" }, 400));
// … messages ausente/inválido    → return fail(json({ ... }, 400));
// … cada validação de mensagem   → return fail(json({ ... }, 400));
// … catch do fetch do gateway    → return fail(json({ error: "AI gateway unreachable" }, 502));
// … !aiRes.ok (429 / 402 / 502)  → return fail(json({ ... }, <status>));
// … resposta vazia               → return fail(json({ error: "Resposta vazia da IA" }, 502));
```

O retorno de sucesso (`return json({ reply })`) **não** leva `fail`.

> O frontend também precisa mandar `Authorization: Bearer <token>` na chamada do
> chat, do mesmo jeito que o `identifyPlantFromPhoto` faz com
> `await ensureAccessToken()`. Sem isso o chat passa a tomar 401.

---

## 2. Seed das 8 plantas em `plant_catalog`

**Problema:** a migration `20260822173709` cria a tabela sem nenhum INSERT. Se a
home lê do banco, mostra catálogo vazio.

**Não transcreva as 8 plantas à mão.** São ~200 linhas de JSON cada, com dose de
nutriente e diagnóstico — transcrever é onde entra erro. Gere a partir do
`plants.ts`, que já é a fonte da verdade.

### Script de seed

Crie `scripts/seed-catalog.ts` no projeto:

```ts
import { createClient } from "@supabase/supabase-js";
import { DB } from "../src/components/smart-garden/plants";

const url = process.env["SUPABASE_URL"]!;
const serviceKey = process.env["SUPABASE_SERVICE_ROLE_KEY"]!;
const db = createClient(url, serviceKey);

const slugKey = (s: string) =>
  s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "") || "planta";

for (const [key, plant] of Object.entries(DB)) {
  // Assets importados (orquídea, palmeira, lavanda) viram string de bundler,
  // não URL utilizável a partir do banco. Guarde null e deixe a UI usar o
  // fallback, ou suba o arquivo para o Storage antes e use a URL pública.
  const img =
    typeof plant.img === "string" && plant.img.startsWith("http") ? plant.img : null;

  const { error } = await db.from("plant_catalog").upsert(
    {
      key: slugKey(plant.sci),
      name: plant.name,
      sci: plant.sci,
      img,
      data: { ...plant, img: img ?? "", thumb: img ?? "", source: "seed", careAvailable: true },
      source: "seed",
      confidence: 1,
    },
    { onConflict: "key" },
  );
  if (error) console.error(key, error.message);
  else console.log("ok", key, plant.sci);
}
```

`source: 'seed'` importa: é o valor que o `saveToCatalog` em
`src/lib/plant-sources.ts` já trata como "tem plano de cuidado" e protege de ser
sobrescrito por uma resposta de GBIF/Wikipédia, que não tem cuidado nenhum.

### As 3 plantas com imagem importada

`orquidea`, `palmeira` e `lavanda` usam `import plantOrchid from '@/assets/...'`.
O valor em tempo de execução é um caminho gerado pelo bundler — gravado no banco
e servido depois, quebra. Duas saídas:

1. **Subir os arquivos para o Supabase Storage** (bucket público) e gravar a URL
   pública. É a solução certa.
2. Gravar `img = null` e deixar a UI cair no placeholder até (1) acontecer.

O script acima já faz (2) por segurança — nunca grava um caminho de bundler.

### Conferir depois

```sql
SELECT key, name, sci, source, (img IS NOT NULL) AS tem_imagem
FROM public.plant_catalog
ORDER BY name;
```

Esperado: 8 linhas, todas com `source = 'seed'`.

---

## 3. Tela "Todas as plantas"

**Problema:** não existe rota nova em `src/routes/`. O catálogo cresce, mas não
há onde vê-lo — que era o ponto da feature.

**Arquivo novo:** `src/routes/plantas.tsx`

Requisitos, na ordem de importância:

1. **Lista tudo de `plant_catalog`.** Leitura é pública (policy
   `catalog is publicly readable`), então dá para consultar direto pelo client
   Supabase, sem rota de API nova.
2. **Busca por nome popular e científico.** Há índices em `lower(name)` e
   `lower(sci)` — use `ilike` nos dois com `%termo%`.
3. **Mostra a procedência de cada planta.** O campo `source` já vem: `seed`
   (catálogo inicial), `ai`, `plantnet`, `gbif`, `wikipedia`.
4. **Marca visualmente as que estão sem plano de cuidado completo** — as de
   `gbif`/`wikipedia` têm `careAvailable: false` no `data`. Um selo discreto
   ("sem plano de cuidado") já resolve; o importante é a pessoa não abrir
   esperando rega e adubação e achar que o app está quebrado.
5. **Link a partir da home**, ao lado de "Plantas comuns".

Reaproveite o card e os tokens que a home já usa — nada de visual novo.

---

## Ordem sugerida

1. **Ligar o conector AI** no painel (grátis, destrava o app inteiro)
2. Patch 1 — cota do chat (é buraco de custo aberto)
3. Seed — sem ele a home pode estar vazia
4. Tela "Todas as plantas"
