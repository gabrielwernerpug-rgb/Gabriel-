# Roadmap

Melhorias priorizadas, levantadas a partir da leitura do código das duas
implementações. Cada item diz **o que está errado hoje**, não só o que fazer.

Prioridade: 🔴 crítico · 🟠 alto · 🟡 médio · ⚪ baixo

> **Estado em 12/08:** o push de lembretes foi implementado no Lovable (commit
> `01f5903a`), mas os créditos do workspace acabaram antes da rodada de
> correções. O P0 abaixo **precisa ser resolvido antes de publicar o app**.

---

## ✅ ~~P0 — `/api/public/send-reminders` está aberto para qualquer um~~ (resolvido em `32fa1db4`)

> Corrigido: o handler compara `x-cron-secret` com o secret `CRON_SECRET` em
> tempo constante **antes** de qualquer acesso ao banco, o handler GET foi
> removido, a resposta virou `{ ok: true }` (contagens só no log), e o endpoint
> falha fechado se o secret não estiver configurado. Registro do problema
> original abaixo.

Introduzido junto com o push, no commit `01f5903a`.

O endpoint que dispara as notificações **não confere autenticação nenhuma** e roda
com `supabaseAdmin` (service role). O agendamento no `pg_cron` manda um header
`apikey` com a chave **publicável** — que é pública por definição, vai no bundle
do frontend — e o handler nem lê esse header.

Consequências:

- Qualquer pessoa pode chamar o endpoint e disparar o loop de envio, que faz
  query no banco e uma requisição HTTP de saída por assinatura registrada.
  É amplificação de custo e vetor de DoS.
- O handler aceita **GET** além de POST. Isso muda estado: crawler, prefetch de
  navegador e link colado em chat disparam o envio sozinhos.
- A resposta devolve `{due, sent, removed}`, expondo publicamente quantos
  lembretes existem no sistema inteiro.

O que **não** dá para fazer por esse furo: mandar notificação arbitrária para um
usuário. `claim_due_reminders` só retorna lembrete genuinamente vencido e já
marca `last_sent_at` na mesma operação. O estrago é custo, disponibilidade e
vazamento de contagem — não sequestro de notificação.

**Correção:**

1. Criar o secret `CRON_SECRET` no projeto, com valor aleatório forte.
2. Na entrada do handler, **antes de qualquer acesso ao banco**, comparar um
   header `x-cron-secret` com `CRON_SECRET`; se não bater, 401 e para ali.
   Comparação em tempo constante, não `===` puro.
3. **Remover o handler GET.** Só POST.
4. Atualizar o `cron.schedule` para mandar `x-cron-secret` no lugar da `apikey`.
5. Responder só `{ ok: true }`. As contagens ficam no log do servidor.

**Esforço:** baixo. **Impacto:** crítico — é o que bloqueia a publicação.

---

## 🔴 P1 — A foto do usuário é descartada

**Hoje:** `garden-store.ts` troca qualquer data URL base64 por uma imagem
genérica do Unsplash antes de gravar no banco:

```ts
const stripDataUrl = (v) => !v || v.startsWith("data:") ? FALLBACK_IMG : v;
```

O usuário fotografa a própria planta, recebe o diagnóstico, e ao recarregar a
página **a foto dele sumiu** — a planta volta com uma imagem de banco de imagens
que não é a dele. Para um app cujo fluxo inteiro começa em "tire uma foto da sua
planta", isso quebra a percepção de que o app guardou alguma coisa.

Não gravar base64 no Postgres foi a decisão certa. A que falta é a outra metade:

**Ação:** usar **Supabase Storage**.
1. Criar bucket `plant-photos`, com RLS por `auth.uid()` no path (`{user_id}/...`)
2. No upload, subir o arquivo e guardar só a URL pública/assinada
3. `sanitizePlantForDb` passa a receber uma URL de verdade e não precisa mais do
   fallback
4. Comprimir no cliente antes de subir (canvas, ~1200px, JPEG q80) — as fotos de
   celular chegam com 3–8 MB

**Esforço:** médio. **Impacto:** alto — é a memória do app.

---

## ⚪ Correção de um erro deste documento — rate limit

Uma versão anterior deste roadmap afirmava que o rate limit era *"10 req/min por
IP, em memória, que zera no redeploy e não vale entre instâncias"*. **Isso estava
errado.** O `api-guard.ts` sempre usou um RPC `rate_limit_hit` persistido no
banco, compartilhado entre instâncias e resistente a redeploy.

A parte que estava certa era só a chave: `identify-plant:${clientIp(request)}`,
por IP — o que penaliza quem divide rede (escola, escritório, CGNAT de operadora).

Isso foi resolvido no commit `32fa1db4` adicionando uma segunda camada por
usuário, sem remover a primeira. Veja em [Feito](#-feito).

Detalhe de comportamento que vale conhecer: tanto `rateLimit` quanto `aiQuotaHit`
**falham abertos** — se o banco der erro, a requisição passa em vez de ser
bloqueada. É uma escolha defensável (uma falha de banco não derruba o app), mas
significa que uma instabilidade no Postgres desliga o limite por completo.

---

## ✅ ~~P3 — Furo pequeno na RLS de `plant_messages`~~ (resolvido em `32fa1db4`)

> Corrigido: a policy de INSERT agora exige que exista um `plant_chats` com
> aquele `id` e `user_id = auth.uid()`. Registro do problema original abaixo.

A política de INSERT valida `auth.uid() = user_id`, mas **não valida que o
`chat_id` pertence a quem está inserindo**. Em tese um usuário pode inserir
mensagens em uma conversa de outra pessoa (informando o próprio `user_id` e um
`chat_id` alheio).

Ele não consegue *ler* essas mensagens de volta — a política de SELECT filtra por
`user_id` — então não há vazamento de dados. Mas dá para poluir a conversa de
outro usuário.

**Ação:** amarrar o `chat_id` ao dono na política de INSERT:

```sql
CREATE POLICY "own messages insert" ON public.plant_messages
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM public.plant_chats c
      WHERE c.id = chat_id AND c.user_id = auth.uid()
    )
  );
```

**Esforço:** trivial. **Impacto:** médio.

---

## 🟡 P4 — Fotos das plantas: aplicar no app e gerar a última

4 das 5 espécies que usavam hotlink direto ao Unsplash já têm foto gerada e
otimizada em `assets/plants/`. Falta a **samambaia** (*Nephrolepis exaltata*) —
as tentativas bateram em `429 rate_limit_reached`; é só repetir mais tarde. O
prompt está pronto em [`assets/plants/MANIFEST.md`](../assets/plants/MANIFEST.md).
Custo: 0,15 crédito por imagem no modelo `z_image`.

**Falta também aplicar as imagens no projeto Lovable** — hoje elas existem só
aqui no repositório. No app, `plants.ts` continua com os hotlinks. Para cada
planta: salvar o arquivo em `src/assets/`, importar no topo de `plants.ts` (mesmo
padrão de `plant-orchid.jpg`) e apontar `img` e `thumb` para o import.

**Esforço:** trivial. **Impacto:** médio — consistência visual e 5 hotlinks a menos.

---

## 🟡 P5 — Decidir entre as duas implementações

Manter dois apps com o mesmo produto significa implementar cada feature duas
vezes — e já divergiram (diário, share e admin só existem no Emergent; o Lovable
tem SSR, o catálogo local mais rico e agora o push). As opções reais:

- **Ficar no Lovable** e portar diário + share + admin.
- **Ficar no Emergent** e portar o catálogo de 8 plantas, o visual e o push.
- **Lovable como front, Emergent como API.** Só faz sentido se o backend do
  Emergent for mesmo o destino de longo prazo.

**Ação:** decisão do dono. Enquanto não houver decisão, evitar implementar
feature nova em ambos.

---

## ⚪ P6 — Ajustes menores

- **Lembrete criado depois do horário dispara no mesmo dia.** Em
  `claim_due_reminders` a condição é `hora_atual >= r.time` com `last_sent_at`
  nulo. Quem criar um lembrete de 08:00 às 10:00 recebe a notificação na hora.
  Discutível se é bug ou conveniência — decidir e deixar explícito.
- **`SmartGarden.tsx` concentra toda a UI** em um arquivo só. Vale quebrar por
  tela (identificação, detalhe, chat, lembretes) quando for mexer nele de novo.
- **`conf` é string fixa no catálogo** (`'97% de confiança'`), enquanto a
  identificação por IA devolve `confidence` numérico. Dois formatos para a mesma
  ideia — unificar em número e formatar na view.

---

## ✅ Feito

- **Push de lembretes** (commit `01f5903a`) — service worker, `push.ts`, tabela
  `push_subscriptions` com RLS, colunas `timezone`/`last_sent_at`/`updated_at` em
  `reminders`, `claim_due_reminders()` com `FOR UPDATE SKIP LOCKED`, limpeza de
  assinatura morta em 404/410, e `pg_cron` a cada 5 minutos.
- **Autenticação do disparo de push** (`32fa1db4`) — `CRON_SECRET` com comparação
  em tempo constante, só POST, resposta sem contagens.
- **RLS de `plant_messages`** (`32fa1db4`) — `chat_id` amarrado ao dono no INSERT.
- **Cota diária por usuário** (`32fa1db4`) — tabela `ai_usage` com
  `PRIMARY KEY (user_id, day)`, `ai_usage_hit()` com upsert atômico
  (`ON CONFLICT ... DO UPDATE SET count = u.count + 1 RETURNING count`), 20
  identificações/dia, e `ai_usage_refund()` devolvendo a cota em **todos** os
  caminhos de erro do `identify-plant` (gateway fora, JSON inválido, 402, 502).
  O limite por IP continua como primeira camada.
- **Endurecimento de privilégios** (`32fa1db4`) — `EXECUTE` revogado de
  `anon`/`authenticated` em `ai_usage_hit`, `ai_usage_refund`,
  `claim_due_reminders` e `rate_limit_hit`. O refund em especial não podia ficar
  exposto: quem pudesse chamá-lo zeraria a própria cota à vontade.
- **Fotos geradas e otimizadas** — 4 das 5 (veja `assets/plants/`).
