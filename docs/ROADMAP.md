# Roadmap

Melhorias priorizadas, levantadas a partir da leitura do código das duas
implementações. Cada item diz **o que está errado hoje**, não só o que fazer.

Prioridade: 🔴 crítico · 🟠 alto · 🟡 médio · ⚪ baixo

---

## 🔴 P0 — Destravar o Emergent

O build está parado por **créditos esgotados** desde 09/08. As três mudanças da
iteração 3 estão escritas mas **nunca foram testadas de ponta a ponta**, porque o
testing agent foi cortado antes de executar.

**Ação:** recarregar créditos e rodar o testing agent até o fim, cobrindo:

1. Correção do login (race condition no `AuthCallback`)
2. Rate limit de 20/dia no Mongo — **incluindo o rollback do contador quando a
   análise falha** (se a chamada ao LLM quebra, a cota do usuário não pode ser
   consumida)
3. Tokens visuais aplicados
4. Regressão: identificação por foto, chat com memória, diário, lembretes
   (due + upcoming), link de compartilhar, admin

Nenhuma linha precisa ser reescrita antes disso. É só verificação.

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

## 🟠 P2 — Rate limit do Lovable não resiste a nada

**Hoje:** `api-guard.ts` faz 10 req/min **por IP, em memória**.

Três problemas:
- **Some no redeploy** — o contador zera a cada build
- **Não vale entre instâncias** — com mais de um processo, cada um tem o seu
  contador, e o limite real vira `10 × nº de instâncias`
- **Por IP pune quem não devia** — uma escola, um escritório ou um CGNAT de
  operadora compartilham IP; um usuário ativo bloqueia os outros

O Emergent **já resolveu isso do jeito certo**: contador por usuário, persistido,
com `$inc` atômico e upsert. Vale portar a mesma ideia para o Supabase.

**Ação:** tabela `ai_usage (user_id, day, count)` com `PRIMARY KEY (user_id, day)`
e upsert atômico:

```sql
INSERT INTO ai_usage (user_id, day, count) VALUES (auth.uid(), current_date, 1)
ON CONFLICT (user_id, day) DO UPDATE SET count = ai_usage.count + 1
RETURNING count;
```

Manter o limite por IP como segunda camada (protege o endpoint antes do login
anônimo), mas o limite que conta é o por usuário.

**Importante:** devolver a cota se a chamada ao LLM falhar — senão um erro do
gateway consome a análise do usuário.

**Esforço:** baixo. **Impacto:** alto — é custo direto de API.

---

## 🟠 P3 — Os lembretes não lembram

**Hoje:** a tabela `reminders` guarda `freq`, `time`, `amount` e `enabled`, e a UI
deixa criar e ligar/desligar. Mas **não existe nada que dispare a notificação**.

O pedido original era explícito: *"uma parte de lembretes que a pessoa bota para
mandar uma notificação no celular de quando tempo e quanto botar água"*. Hoje o
lembrete é um registro no banco que ninguém lê.

**Ação:**
1. Service worker + Web Push (VAPID), com permissão pedida no momento em que o
   usuário cria o primeiro lembrete — nunca no load da página
2. Supabase Edge Function agendada (`pg_cron`) varrendo lembretes `enabled` cujo
   horário chegou
3. Guardar `last_sent_at` para não disparar duas vezes
4. **Guardar o timezone do usuário.** `time` é um `text` como `"08:00"` — sem
   timezone, um lembrete das 8h dispara na hora errada para metade dos usuários

**Esforço:** alto. **Impacto:** alto — é uma feature prometida que não existe.

---

## 🟡 P4 — Fotos das plantas: aplicar no app e gerar a última

4 das 5 espécies que usavam hotlink direto ao Unsplash já têm foto gerada e
otimizada em `assets/plants/`. Falta a **samambaia** (*Nephrolepis exaltata*) —
duas tentativas bateram em `429 rate_limit_reached`; é só repetir mais tarde. O
prompt está pronto em [`assets/plants/MANIFEST.md`](../assets/plants/MANIFEST.md).
Custo: 0,15 crédito por imagem no modelo `z_image`.

**Falta também aplicar as imagens no projeto Lovable** — hoje elas existem só
aqui no repositório. No app, `plants.ts` continua com os hotlinks. Para cada
planta: salvar o arquivo em `src/assets/`, importar no topo de `plants.ts` (mesmo
padrão de `plant-orchid.jpg`) e apontar `img` e `thumb` para o import.

**Esforço:** trivial. **Impacto:** médio — consistência visual e 5 hotlinks a menos.

---

## 🟡 P5 — Furo pequeno na RLS de `plant_messages`

A política de INSERT valida `auth.uid() = user_id`, mas **não valida que o
`chat_id` pertence a quem está inserindo**. Em tese um usuário pode inserir
mensagens em uma conversa de outra pessoa (informando o próprio `user_id` e um
`chat_id` alheio).

Ele não consegue *ler* essas mensagens de volta — a política de SELECT filtra por
`user_id` — então não há vazamento de dados. Mas dá para poluir a conversa de
outro usuário, e a mensagem apareceria para o dono do chat se a leitura algum dia
passar a filtrar por `chat_id`.

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

## 🟡 P6 — Decidir entre as duas implementações

Manter dois apps com o mesmo produto significa implementar cada feature duas
vezes — e já divergiram (diário, share e admin só existem no Emergent; o Lovable
tem SSR e um catálogo local mais rico).

Não dá para decidir isso sem o dono do projeto. As opções reais:

- **Ficar no Lovable** e portar diário + share + admin. Front melhor, backend a
  reconstruir.
- **Ficar no Emergent** e portar o catálogo de 8 plantas e o visual. Backend mais
  completo, mas hoje bloqueado.
- **Lovable como front, Emergent como API.** Só faz sentido se o backend do
  Emergent for mesmo o destino de longo prazo — senão adiciona uma rede no meio
  sem ganho.

**Ação:** decisão do dono. Enquanto não houver decisão, evitar implementar feature
nova em ambos.

---

## ⚪ P7 — Ajustes menores

- **`reminders` não tem `updated_at`** nem trigger, ao contrário de `plant_chats`.
  Sem isso não dá para saber quando um lembrete foi alterado.
- **`SmartGarden.tsx` concentra toda a UI** em um arquivo só. Vale quebrar por
  tela (identificação, detalhe, chat, lembretes) quando for mexer nele de novo.
- **`conf` é string fixa no catálogo** (`'97% de confiança'`), enquanto a
  identificação por IA devolve `confidence` numérico. Dois formatos para a mesma
  ideia — unificar em número e formatar na view.
