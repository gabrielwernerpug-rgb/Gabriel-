# Análise completa — Smart Garden IA

**Data:** 27/09/2026 · **Projeto Lovable:** `ae9ae530-ced6-41c2-a9d9-8f939661629d` · **Commit analisado:** `23a17d7`

Este documento é a análise final: tudo que precisa ser corrigido, ajustado ou
acrescentado. Cada item traz **o problema**, **a prova** (arquivo ou consulta ao
banco), **por que importa**, **a correção** e **como testar**. Está escrito para
virar prompt: dá para copiar item por item.

---

## Como a análise foi feita

- Li **todos** os arquivos de código do app: `identify-plant.ts`, `chat-plant.ts`,
  `send-reminders.ts`, `vapid-key.ts`, `api-guard.ts`, `plant-sources.ts`,
  `garden-store.ts`, `catalog.ts`, `account.functions.ts`, `push.ts`, `sw.js`,
  `SmartGarden.tsx`, `plants.ts`, `auth.tsx`, `plantas.tsx`, `index.tsx`,
  `__root.tsx`, `server.ts`, os clientes do Supabase e as migrations mais recentes.
- Consultei o **banco de produção**: tabelas, políticas de segurança (RLS),
  permissões de cada função, gatilhos, agendamento (cron), respostas HTTP do cron
  e a contagem de usuários e dados.
- Conferi os **termos de uso do Pl@ntNet** direto no site deles.

### O que eu não consegui verificar

- **Não testei clicando no app.** A prévia do Lovable é privada (responde `401`
  para quem está fora da sua conta) e o app não está publicado.
- **Não sei se a chave nova do Pl@ntNet funciona.** Ela fica no cofre do
  projeto e eu não a vejo. O teste da Fase 1 confirma.
- A ferramenta do banco **parou de responder** no fim da análise. Ficaram sem
  conferir: os índices, os *buckets* de armazenamento e a lista exata dos 14
  avisos de segurança. Pelo código, não existe nenhum bucket.

---

## A foto de hoje, em números (banco de produção)

| O quê | Valor | O que significa |
|---|---|---|
| Usuários | **19** | — |
| Usuários com conta Google | **0** | Todos os 19 são **anônimos**. Ninguém entrou com Google até hoje — nem você. |
| Usuários Pro | **0** | Ninguém em teste grátis. |
| Identificações registradas | **0** | A tabela de uso está vazia: o fluxo atual de identificação **nunca rodou de ponta a ponta**. |
| Plantas no catálogo | **8** | Só as 8 iniciais. O catálogo ainda não cresceu. |
| Correções de usuários | **0** | — |
| Lembretes / inscrições de notificação | **0 / 0** | — |
| Chamadas do cron nas últimas 24h | **72, todas `404`** | Os lembretes **nunca foram enviados** (item A7). |

**Conclusão:** o código evoluiu muito, mas o app **nunca foi usado de verdade**
na versão atual. Os itens abaixo são o que falta para ele funcionar com gente de
verdade.

---

## Resumo: os 12 bloqueadores

Sem estes, **não dá para publicar nem mostrar ao seu tio**:

1. **A1** — Qualquer pessoa na internet consegue zerar a própria cota (e mexer na dos outros).
2. **A2** — Contas anônimas furam a exigência de login e a cota.
3. **A3** — Não existe botão de **Entrar**, **Sair** ou **Minha conta** no app.
4. **A4** — O **teste grátis de 14 dias não existe**, e um Pro de teste nunca expiraria.
5. **A5** — **Cada mensagem de chat gasta uma identificação.** E o chat não confere o plano.
6. **A6** — Para quem é grátis, chat e lembrete **falham em silêncio**: a tela finge que salvou.
7. **A7** — Os lembretes nunca foram enviados, e **no iPhone nunca serão** do jeito que está.
8. **A8** — Qualquer usuário consegue **gravar planta inventada no catálogo público**.
9. **A9** — A foto vai para o servidor **sem compressão** (3–8 MB): lento e falha no 4G.
10. **A10** — A tela de resultado **fica vazia ou quebra** quando falta plano de cuidado.
11. **A11** — Num domínio próprio, **toda chamada vai dar erro 403**.
12. **A12** — Pl@ntNet: atribuição obrigatória, limite de 500/dia e **risco de banimento da conta**.

---

# PARTE A — Bloqueadores 🔴

## A1. Funções de cota abertas para qualquer pessoa na internet

**Problema.** As funções do banco que contam e devolvem cota podem ser chamadas
por **qualquer pessoa**, até sem login, usando a chave pública que vai dentro do
site.

**Prova.** Permissões lidas no banco (`proacl`):

| Função | Quem pode executar hoje |
|---|---|
| `ai_usage_refund_kind` | **todo mundo** (`PUBLIC`) |
| `ai_usage_hit_kind` | **todo mundo** |
| `ai_usage_refund` | **todo mundo** |
| `ai_usage_hit` | **todo mundo** |
| `user_plan` | **todo mundo** |

A causa está na migration `20260910161901`: ela faz
`REVOKE ... FROM anon, authenticated`, mas **esquece o `PUBLIC`**. No Postgres,
toda função nasce executável por `PUBLIC`, e `anon`/`authenticated` herdam de
lá. Então o `REVOKE` não teve efeito. É o **mesmo buraco que já tinha sido
fechado em agosto**, e que voltou.

**Por que importa.**
- Um usuário grátis chama `ai_usage_refund_kind` e **zera a própria cota** →
  identificações ilimitadas, e a conta de IA quem paga é você.
- Dá para chamar `ai_usage_hit_kind` com o id de **outro** usuário e esgotar a
  cota dele.
- Dá para criar linhas infinitas em `ai_usage` com ids aleatórios e **encher o
  banco**.
- `user_plan` revela o plano de qualquer usuário.

**Correção** (SQL, numa migration nova):

```sql
REVOKE ALL ON FUNCTION public.ai_usage_hit(uuid, integer)                       FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ai_usage_refund(uuid)                             FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ai_usage_hit_kind(uuid, text, integer, integer)   FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.ai_usage_refund_kind(uuid, text)                  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ai_usage_hit_kind(uuid, text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.ai_usage_refund_kind(uuid, text)                TO service_role;

-- user_plan é usada pelas políticas de segurança: fica só para usuário logado.
REVOKE ALL ON FUNCTION public.user_plan(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.user_plan(uuid) TO authenticated, service_role;

-- Impede que isso volte: função nova não nasce mais pública.
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
```

Depois do A5, apague de vez `ai_usage_hit` e `ai_usage_refund`: elas deixam de
ser usadas.

**Como testar.**
```sql
SELECT p.proname,
       has_function_privilege('anon', p.oid, 'EXECUTE')          AS anon,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') AS logado
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.prosecdef;
```
Esperado: `anon = false` em **todas**, e `logado = true` **só** em `user_plan`.

---

## A2. Contas anônimas furam o login e a cota

**Problema.** A regra é "para identificar, precisa entrar com o Google". Mas o
servidor aceita qualquer token válido, **inclusive de conta anônima**.
`userIdFromRequest` (`api-guard.ts`) não olha a marca `is_anonymous`.

**Prova.** Existem **19 contas anônimas** no banco e **nenhuma** Google. O
frontend parou de criar conta anônima (`validSession` em `garden-store.ts`), mas
o **servidor** continua aceitando esse tipo de conta.

**Por que importa.** Se o login anônimo estiver ligado no projeto, um script
cria contas anônimas sem parar, cada uma com 3 identificações grátis → **IA
infinita de graça**. E fura a regra "tem que fazer login".

**Correção.**
1. Em `userIdFromRequest`: se `claims.is_anonymous === true`, retornar `null`
   (vira 401).
2. Fazer o mesmo no `requireSupabaseAuth` das *server functions*.
3. **Desligar o login anônimo** em Cloud → Users/Auth → Providers.
4. Apagar as 19 contas anônimas antigas (o `ON DELETE CASCADE` leva junto
   conversas e perfis delas).
5. Remover o código morto de "vincular dados anônimos": `claimAnonymousData` em
   `account.functions.ts`, a chave `sg:anon-token` e os dois blocos em `auth.tsx`.
   Ninguém mais tem sessão anônima para vincular.

**Como testar.** Chamar `/api/identify-plant` com token de conta anônima →
**401**. `SELECT count(*) FROM auth.users WHERE is_anonymous` → **0**.

---

## A3. Não existe botão de entrar, sair ou "minha conta"

**Problema.** O app exige login, mas **não mostra em lugar nenhum** onde entrar.
`loadAccount()` e `signOut()` existem em `garden-store.ts`, mas **nenhuma tela
usa**. A única forma de chegar em `/auth` é digitar o endereço.

**Prova.** Os imports de `SmartGarden.tsx` não trazem `loadAccount` nem
`signOut`. A resposta 401 aparece só como texto vermelho ("Entre na sua
conta…"), sem botão.

**Por que importa.** É a primeira coisa que seu tio vai fazer: tirar uma foto.
Hoje ele recebe um erro e **não tem para onde ir**.

**Correção.**
1. **Cabeçalho fixo na home.**
   - Deslogado: botão **"Entrar"**.
   - Logado: foto do Google + selo do plano (**Grátis** / **Pro · teste até
     10/10**) + menu com **Minha conta** e **Sair**.
2. **Pedir login antes da câmera.** Ao tocar em "Abrir câmera ou galeria"
   deslogado, abrir um aviso "Entre para identificar" com o botão do Google,
   **antes** de a pessoa escolher a foto. Assim ela não perde a foto.
3. **Qualquer 401 vira botão** "Entrar com Google", nunca só texto.
4. **Página `/conta`**, com:
   - plano atual e dias restantes de teste;
   - uso do mês (ex.: "2 de 3 identificações");
   - botão **Assinar Pro** (item E3);
   - **Sair**;
   - **Excluir minha conta e meus dados** (item D1).
5. Depois do login, voltar para a tela em que a pessoa estava.

**Como testar.** Aba anônima → a home mostra "Entrar" → tocar na câmera abre o
aviso de login → entrar → volta para a home já logado, com o selo do plano.

---

## A4. O teste grátis de 14 dias não existe

**Problema.**
- Não há **nenhum gatilho** que crie o perfil no cadastro. O perfil só nasce
  dentro de `getUserPlan`, sempre como `free`, e **nada** preenche
  `trial_ends_at`.
- Nem `user_plan()` (SQL) nem `getUserPlan()` (TypeScript) **olham a data do
  teste**. Um Pro de teste **nunca expiraria**.
- As duas funções leem o plano cada uma do seu jeito, e podem discordar.

**Prova.** Os únicos gatilhos do banco são os de `updated_at`. Os 19 perfis
estão `free`, `trial_ends_at = null`.

**Correção.**
1. **Gatilho `AFTER INSERT ON auth.users`** (só para conta não anônima): cria o
   perfil com `plan='pro'`, `subscription_status='trialing'` e
   `trial_ends_at = now() + interval '14 days'`.
2. **Uma regra só para "é Pro?"**, dentro de `user_plan()`:
   ```sql
   CASE
     WHEN p.plan = 'pro' AND p.subscription_status IN ('active','manual') THEN 'pro'
     WHEN p.plan = 'pro' AND p.subscription_status = 'trialing' AND p.trial_ends_at > now() THEN 'pro'
     ELSE 'free'
   END
   ```
3. `getUserPlan()` passa a **chamar `user_plan` pelo banco** em vez de ler a
   coluna. Uma regra, um lugar.
4. **Um teste por pessoa.** Para quem apagar a conta e criar outra não ganhar
   14 dias de novo, guarde num `trial_claims` o hash do e-mail de quem já usou o
   teste.
5. **Avisar na tela:** "Seu teste Pro termina em 3 dias" e, quando acabar, "Seu
   teste terminou — veja o que continua grátis".
6. Trocar a mensagem do limite grátis: hoje diz "o plano Pro **chega em breve**",
   o que contradiz o teste.

**Como testar.** Conta Google nova → perfil `pro/trialing` com 14 dias. Mudar
`trial_ends_at` para ontem → `user_plan` devolve `free`, chat e lembretes
bloqueiam, e a tela avisa.

---

## A5. Cada mensagem de chat gasta uma identificação

**Problema.** O chat usa a função antiga `aiQuotaHit` → `ai_usage_hit`, que
**grava no contador `identify`**:

```sql
VALUES (_user_id, _day, 'identify', 1)   -- dentro de ai_usage_hit
```

Resultado:
- Usuário grátis manda 3 mensagens no chat → **não consegue mais identificar**
  no mês.
- Usuário Pro manda 20 mensagens → identificação bloqueada no dia.
- **O chat não confere o plano:** `PLAN_LIMITS.free.chat = false`, mas o
  `chat-plant.ts` nunca olha o plano. O grátis conversa com a IA (e você paga).
  Só não salva, porque o banco recusa (item A6).
- `aiQuotaHit` **falha aberto**: se o banco der erro, libera tudo.

**Correção** (`chat-plant.ts`):
1. `const plan = await getUserPlan(userId)`. Se `!PLAN_LIMITS[plan].chat` →
   **403** `{ error: "pro_required", message: "O chat com a IA é do plano Pro." }`.
2. Trocar por `quotaHitKind(userId, "chat", PLAN_LIMITS[plan].chatDaily, null)`
   e devolver com `quotaRefundKind(userId, "chat")`, que falha fechado.
3. Tirar a constante solta `DAILY_USER_LIMIT = 60` e usar `PLAN_LIMITS`.
4. Apagar `aiQuotaHit` e `aiQuotaRefund` do `api-guard.ts`, e as funções SQL
   `ai_usage_hit` e `ai_usage_refund`.

**Como testar.** Pro manda 5 mensagens → `ai_usage` tem `kind='chat', count=5`
e **`identify` não mudou**. Grátis tenta o chat → 403 com a tela de upgrade.

---

## A6. Chat e lembretes falham em silêncio para quem é grátis

**Problema.** O banco só deixa **gravar** conversa, mensagem e lembrete se o
plano for Pro (políticas `own chats insert`, `own messages insert`,
`own reminders insert`). Mas a tela:
- mostra o botão **"Continuar no chat"** para todo mundo;
- **mostra o lembrete como criado** na hora (`setReminders` antes de salvar) e,
  quando o banco recusa, só escreve no console;
- faz o mesmo com as mensagens do chat.

No recarregar, **tudo some**. A pessoa acha que o app perdeu os dados dela.

**Correção.**
1. Carregar o plano ao abrir o app (`loadAccount`) e guardar num estado.
2. Grátis: no lugar do chat e dos lembretes, mostrar um **cartão Pro**
   ("Converse com a IA sobre sua planta — incluso no Pro. Teste 14 dias
   grátis") em vez de deixar tentar.
3. **Não fingir sucesso.** Se `insertReminder`, `ensureChat` ou `saveMessage`
   devolverem erro, desfazer na tela e avisar ("Não consegui salvar. Tente de
   novo.").

**Como testar.** Conta grátis → chat e lembretes mostram o cartão Pro e nada é
enviado ao banco. Conta Pro → cria lembrete, recarrega a página, o lembrete
continua lá.

---

## A7. Os lembretes nunca foram enviados — e no iPhone nunca serão

**Problema 1 — o cron bate numa página que não existe.** O agendamento chama
`https://project--ae9ae530-….lovable.app/api/public/send-reminders` a cada 5
minutos. As **72 respostas das últimas 24h foram `404`**. O app não está
publicado, então esse endereço não existe.

**Problema 2 — iPhone e iPad.** No iPhone, notificação de site **só funciona se
o site estiver instalado na Tela de Início** (iOS 16.4+), e isso exige um
**manifesto de app**. O projeto **não tem `manifest.json`** (confirmado: `404`),
nem ícones, nem `apple-touch-icon`. Hoje, no Safari, `pushSupported()` devolve
falso e a tela diz "Este navegador não suporta notificações".

**Correção.**
1. **Publicar** o app. Depois, conferir que o cron responde `200`:
   ```sql
   SELECT status_code, count(*) FROM net._http_response
   WHERE created > now() - interval '1 hour' GROUP BY 1;
   ```
   Se o endereço publicado for outro (ex.: `smart-garden-ia.lovable.app` ou
   domínio próprio), **reagendar o cron** com o endereço certo. O segredo
   continua vindo de `app_config`, nunca escrito no comando.
2. **Tornar o app instalável:** `public/manifest.webmanifest` (nome, ícones
   192/512, `display: standalone`, cores), `apple-touch-icon`, `theme-color` e o
   link do manifesto no `<head>`.
3. **Ensinar a instalar no iPhone.** Detectar iOS fora do modo instalado e, ao
   criar o primeiro lembrete, mostrar: "Para receber avisos no iPhone: toque em
   **Compartilhar** → **Adicionar à Tela de Início** e abra o app por lá."
4. Conferir se os secrets `VAPID_PUBLIC_KEY` e `VAPID_PRIVATE_KEY` existem.
   `/api/public/vapid-key` responde `503` quando faltam.

**Como testar.** Publicado: criar lembrete para daqui a 5 min → a notificação
chega no Android/Chrome e no iPhone com o app instalado. O banco mostra `200`
nas chamadas do cron.

---

## A8. Qualquer usuário grava planta inventada no catálogo público

**Problema.** O `/api/identify-plant` aceita `chooseSci` e `chooseName` **com
qualquer texto**. Com isso ele:
1. manda o Gemini escrever um plano de cuidado para a "espécie" — e o prompt
   manda **"não questione a espécie"**;
2. grava o resultado no **catálogo público** com `source: "ai"` e
   `confidence: 1`;
3. e, como `source = 'ai'`, o registro fica **protegido de ser sobrescrito**.

**Por que importa.**
- Qualquer usuário grava `"Compre no site X"` ou um palavrão como planta, e isso
  aparece em **"Todas as plantas" para todo mundo**.
- O Gemini inventa rega e adubação para planta que não existe, e isso vira
  "fato" no catálogo.
- Cada chamada gasta IA.

**Correção.**
1. **A escolha precisa ser uma das candidatas que o servidor devolveu.** Ao
   devolver candidatas, gravar numa tabela `identify_sessions`
   (`id, user_id, candidates jsonb, created_at, used boolean`) e devolver o
   `identifyId`. A escolha manda `identifyId + índice`, nunca o nome. Vale 30
   minutos e só uma vez.
2. **Correção pelo "Não é essa planta?"** só aceita espécie que **já existe no
   catálogo**. Se ela não tiver plano de cuidado, validar no GBIF antes
   (`matchType = EXACT`, `rank = SPECIES`) e só então pedir o plano à IA.
3. **Nunca gravar no catálogo** uma espécie que não passou pelo GBIF. Guardar em
   `data.validatedBy = "gbif"`.
4. Tirar o "não questione a espécie" do prompt. Trocar por: "se o nome não for
   uma espécie de planta real, responda `{ "plant": null }`".

**Como testar.** Mandar `chooseSci: "Planta Falsa Teste"` direto na API → **400**,
nada gravado no catálogo, nenhuma chamada à IA.

---

## A9. A foto vai sem compressão

**Problema.** `handleUpload` lê o arquivo original com `FileReader` e envia o
base64 inteiro. Foto de celular tem 3–8 MB, e em base64 vira 4–11 MB.

**Por que importa.**
- No 4G demora muito, e às vezes falha no meio.
- O servidor **não tem limite de tamanho**: aceita qualquer coisa.
- A foto leva a **localização GPS** (EXIF) para o Google e o Pl@ntNet.
- Alguns formatos (HEIC do iPhone) podem não ser aceitos pelo Pl@ntNet.

**Correção.**
1. No navegador, antes de enviar: `createImageBitmap` + `canvas` → lado maior
   **1280 px**, **JPEG qualidade 0,82**. Isso tira o EXIF/GPS, converte HEIC em
   JPEG e deixa a foto com uns 200–400 KB.
2. No servidor: recusar imagem acima de **6 MB** (base64) com **413** e mensagem
   clara. Aceitar só `image/jpeg`, `image/png` e `image/webp`, conferindo os
   primeiros bytes do arquivo, não só o que o cliente diz.

**Como testar.** Foto de 6 MB do celular → no DevTools, a requisição tem menos
de 500 KB. Mandar 10 MB direto na API → 413.

---

## A10. A tela de resultado fica vazia ou quebra

**Problema 1 — sem plano de cuidado.** Quando a planta vem do GBIF/Wikipédia
(`careAvailable: false`), o `ResultBody` desenha **todos os cartões vazios**:
"Frequência de rega" sem número, listas em branco. O tipo `Plant` do frontend
nem tem `careAvailable`, `summary`, `sourceLabel` ou `sourceUrl`, então essas
informações **somem**.

**Problema 2 — JSON torto da IA derruba o app.** A resposta do Gemini é usada
**sem validação** (`...(care as IdentifiedPlant)`). Se vier sem `water`, a linha
`plant.water.freq.match(...)` quebra a tela inteira, e o erro aparece **em
inglês** ("This page didn't load"). E o JSON torto **fica gravado no catálogo**.

**Correção.**
1. **Validar a resposta da IA com `zod`** antes de mostrar e antes de gravar
   (listas no tamanho certo, `v` entre 0 e 100, `c` só `nhi`/`nmd`/`nlo`). Se
   falhar: tentar de novo **uma vez**. Se falhar de novo: tratar como "sem plano
   de cuidado".
2. Acrescentar ao tipo `Plant` do frontend: `careAvailable`, `summary`,
   `sourceLabel`, `sourceUrl`, `taxonomy`.
3. Quando `careAvailable === false`, **não desenhar os cartões de cuidado**.
   Mostrar: "Identificamos a espécie, mas ainda não temos um plano de cuidado
   confiável", o resumo da Wikipédia, o link da fonte e um botão **"Gerar plano
   de cuidado"**.
4. **Mostrar sempre a procedência** em todo resultado. Exemplo: "Identificado
   por Pl@ntNet · Cuidados escritos por IA".
5. Traduzir para português a página de erro e a 404 do `__root.tsx`.

**Como testar.** Forçar `careAvailable: false` → a tela mostra o aviso, o resumo
e a fonte, sem nenhum cartão vazio. Forçar um JSON sem `water` → a tela não
quebra.

---

## A11. Num domínio próprio, toda chamada dá 403

**Problema.** `isAllowedOrigin` (`api-guard.ts`) só aceita `*.lovable.app`,
`*.lovableproject.com` e `localhost`, mais o que estiver em
`ALLOWED_ORIGIN_HOSTS`. Publicou em `smartgardenia.com.br` e esqueceu esse
secret? **Identificação e chat respondem "Origem não permitida"** para todo
mundo.

Ao mesmo tempo, **aceitar qualquer `*.lovable.app` é largo demais**: qualquer
outro app do Lovable passa nessa checagem.

**Correção.**
1. Lista fechada: o endereço publicado do seu app, a prévia
   `id-preview--ae9ae530-….lovable.app` e o domínio próprio, via
   `ALLOWED_ORIGIN_HOSTS`.
2. Se `ALLOWED_ORIGIN_HOSTS` não estiver configurado em produção, **registrar
   um erro no log na primeira chamada**, para você descobrir no mesmo dia.

---

## A12. Pl@ntNet: regras do serviço e a sua conta

Conferido nos [termos do Pl@ntNet](https://my.plantnet.org/terms_of_use) e na
[página de preços](https://my.plantnet.org/pricing):

- **Uso comercial é permitido de graça até 500 identificações por dia.** Acima
  disso, é pago.
- **Atribuição.** Os termos pedem esta frase: *"The image-based plant species
  identification service used, is based on the Pl@ntNet recognition API,
  regularly updated and accessible through the site https://my.plantnet.org/"*.
  Há também logos oficiais.
- ⚠️ **"Não é permitido criar mais de uma conta gratuita por pessoa"**, nem
  várias contas saindo do mesmo IP. Você contou que tentou entrar com **várias
  contas suas**. Fique com **uma só** e apague as outras, se chegaram a ser
  criadas. Senão, arrisca ter a chave cortada.

**Correção.**
1. **Rodapé** (e página "Sobre"): "Identificação de espécies com a tecnologia
   Pl@ntNet", com link para my.plantnet.org.
2. **Teto de 450 chamadas por dia** ao Pl@ntNet, num contador global em
   `ai_usage` (ex.: `user_id` fixo do sistema, `kind='plantnet'`). Passou disso,
   usar só o Gemini até a meia-noite.
3. **Registrar no log** quantas identificações restam no dia. O Pl@ntNet devolve
   esse número na resposta (campo `remainingIdentificationRequests` — confirmar
   o nome exato no retorno real).
4. **Chave.** Se a chave que você colocou nos Secrets é a mesma que passou pelo
   chat (`2b10hq…`), **gere outra** no Pl@ntNet, troque no Secret e apague a
   antiga.

---

# PARTE B — Bugs e ajustes 🟠

## B1. Foto ruim sai de graça, e escolher a candidata cobra de novo

**Hoje:**
- Quando a identificação devolve candidatas, o código **devolve a cota**
  (`fail(...)` dentro de `decide`). Mas o trabalho caro (Pl@ntNet ou Gemini com
  imagem) **já foi feito**. Um usuário grátis que manda sempre foto borrada tem
  **identificações ilimitadas**.
- Depois, ao tocar numa candidata, o app chama a API de novo e **cobra mais uma**.

**Correção: 1 foto = 1 crédito.**
1. Devolver candidatas **conta como identificação**.
2. **Escolher a candidata é grátis** (via `identifyId` do A8).
3. **Só devolver a cota em falha técnica:** IA fora do ar, erro 5xx ou foto sem
   planta.

## B2. Confiança falsa

- Ao escolher uma candidata, a tela mostra **"100% de confiança"** (o servidor
  usa `confidence = 1`). Mostrar **"Escolhida por você"**.
- As 8 plantas do catálogo têm **"97% de confiança" fixo** em `plants.ts`, sem
  foto nenhuma analisada. Mostrar "Do catálogo".
- Planta do catálogo passa por um **"Analisando sua planta… A IA está
  identificando"** falso de 800 ms (`startAnalysis`). Tirar: abre direto.

## B3. Só dá para criar lembrete das 8 plantas do catálogo

O modal lista só `PLANT_KEYS`. **Não dá para criar lembrete da planta que você
acabou de identificar.**

**Correção.** Na tela de resultado, botão **"Criar lembrete de rega"** que abre
o modal já preenchido com a planta, a foto, a frequência e a quantidade do plano
de cuidado. O select do modal passa a listar também "Minhas plantas" (F1).

## B4. "A cada 15 dias" regando a cada 14

Em `SmartGarden.tsx`, `<option value="14">A cada 15 dias</option>` e
`freqLabels["14"] = "A cada 15 dias"`. O banco rega a cada **14**. Trocar o texto
para "A cada 14 dias", ou o valor para 15.

## B5. Lembrete criado depois do horário dispara na hora

`claim_due_reminders`: criou às 10:00 um lembrete das 08:00 → com
`last_sent_at` vazio, dispara no ciclo seguinte. **Correção:** ao criar,
preencher `last_sent_at = now()` quando o horário do dia já passou, e a primeira
rega fica para o próximo ciclo. Ou perguntar na tela: "Começar hoje ou amanhã?".

## B6. O histórico do chat carrega as mensagens mais antigas

`loadChats` busca com `order("created_at", { ascending: true }).limit(600)`, ou
seja, as **600 mais antigas**. Quem conversa muito **perde as conversas
recentes** ao recarregar. **Correção:** buscar as 50 mais recentes **por
conversa**, em ordem decrescente, e inverter na tela.

## B7. A foto do usuário some ao recarregar

`sanitizePlantForDb` troca a foto por uma imagem genérica do Unsplash
(`FALLBACK_IMG`). **Correção:** bucket `plant-photos` no Storage, **privado**,
com pasta por usuário (`{user_id}/…`) e política por `auth.uid()`. Gravar só o
caminho e mostrar com URL assinada. É a base do diário (F3) e de "Minhas plantas"
(F1).

## B8. "Todas as plantas": os cards não abrem, e a busca quebra

- Os cards de `plantas.tsx` **não têm clique**. A pessoa vê a planta e não
  consegue abrir.
- A busca monta `q.or("name.ilike.%termo%,sci.ilike.%termo%")` com o texto cru.
  **Vírgula, parênteses ou ponto** no termo quebram a consulta, e aparece "Nada
  encontrado". Tirar esses caracteres antes.
- Limite fixo de 200, sem paginação. Pôr "Carregar mais".

## B9. "Não é essa planta?" é um beco sem saída

A busca só procura no catálogo (8 plantas hoje). Se a certa não estiver lá, a
pessoa **não tem o que fazer**. **Correção:** se não achar no catálogo, oferecer:
- "Buscar pelo nome", com validação no GBIF (A8);
- "Tentar com outra foto — de preferência da flor ou do fruto".

## B10. O chat não sabe o que a tela disse — e não consulta nada

- O chat recebe **só o nome** da planta. Não recebe o plano de cuidado mostrado
  na tela. Então ele pode dizer "regue 1× por semana" logo depois de a tela
  dizer "a cada 3 dias". **Correção:** mandar o plano de cuidado (resumido) como
  contexto no *system prompt*, com a instrução "seja coerente com este plano; se
  discordar, explique por quê".
- Você pediu que o chat **"sempre olhe na internet antes de responder"**. Isso
  **não foi feito**. Veja F4.

## B11. Carregamento infinito

Nenhum `fetch` do frontend tem tempo limite, e o "Analisando…" não tem botão de
cancelar. No servidor, o pior caminho soma 15 s (Pl@ntNet) + 20 s (Gemini
imagem) + 20 s (Gemini cuidado) = **55 s**.

**Correção.** `AbortController` de 60 s no frontend, botão **Cancelar**, e a
mensagem "Está demorando mais que o normal…" depois de 15 s.

## B12. Notificações

- O título "Hora de regar sua **${nome}**" fica errado com nome masculino ("sua
  Cacto"). Trocar para "💧 Hora de regar: Cacto".
- **Ao sair da conta**, a inscrição de notificação continua ligada ao aparelho.
  No celular compartilhado, o próximo usuário recebe os avisos do anterior.
  **Correção:** no "Sair", apagar a inscrição do aparelho
  (`pushManager.getSubscription().unsubscribe()` e apagar no banco).
- `VAPID_SUBJECT` cai para `mailto:notificacoes@smartgarden.app` quando não
  configurado. Use um e-mail seu, real.
- Lembrete de quem **perdeu o Pro** continua sendo enviado. Decida: pausar ou
  manter. Se pausar, `claim_due_reminders` filtra por `user_plan = 'pro'`.

## B13. Cara de "app genérico do Lovable"

`__root.tsx`:
- `title: "Lovable App"`, `description: "Lovable Generated Project"`,
  `author: "Lovable"`, `twitter:site: "@Lovable"`;
- `<html lang="en">`;
- 404 e página de erro **em inglês**;
- **sem `og:image`**: link colado no WhatsApp aparece sem imagem;
- `favicon.ico` do modelo, sem ícone próprio do app.

**Correção.** Tudo em português, `lang="pt-BR"`, imagem de compartilhamento
(1200×630) com a marca, favicon e ícones próprios.

## B14. Fotos ainda vindas do Unsplash

Samambaia, costela-de-adão, cacto, girassol e rosa continuam com link direto ao
Unsplash, e a foto grande da home (`HERO_IMG`) também. As 5 fotos próprias **já
estão prontas** em `assets/plants/` no GitHub (ver `MANIFEST.md`). Falta subir
para `src/assets/` e importar.

## B15. Curinga na busca do catálogo

`findInCatalog` usa `.ilike("sci", sci)`. Um nome com `%` ou `_` casa com várias
linhas, e o `maybeSingle()` dá erro. **Correção:** comparar por `key = slugKey(sci)`.

## B16. Código morto para limpar

- `identifyWithPlantNet` (`plant-sources.ts`)
- `aiQuotaHit` e `aiQuotaRefund` (depois do A5)
- `claimAnonymousData` e a lógica de token anônimo (depois do A2)
- `hasStoredSession` (pode virar parte de `validSession`)

## B17. Pequenos

- O preview da conversa em "Minhas conversas" põe "…" mesmo quando a mensagem é
  curta.
- "IA online" é um texto fixo. Tirar, ou mostrar de verdade.
- Remover lembrete não pede confirmação.
- O seletor "O que está na foto?" não tem "Casca/tronco" (`bark`), que o
  servidor já aceita. Útil para árvore.

---

# PARTE C — Barreiras de segurança extras

As que normalmente a IA não coloca sozinha:

| # | Barreira | Por quê |
|---|---|---|
| C1 | **Revogar `PUBLIC`** das funções e mudar o padrão do schema (A1) | Fecha o buraco e impede que volte. |
| C2 | **Limite de tamanho e tipo** da imagem no servidor (A9) | Ninguém manda 50 MB para travar o servidor. |
| C3 | **Validar toda resposta da IA** com `zod` antes de mostrar ou gravar (A10) | IA devolve lixo às vezes, e lixo não pode ir para o catálogo público. |
| C4 | **Chat: não montar o *system prompt* com texto do cliente** | Hoje `plantName` e `plantSci` entram crus nas instruções. Mandar só o `plant_key`/`identifyId` e buscar nome e plano no banco. |
| C5 | **Chat: não aceitar mensagens "assistant" do cliente** | O cliente pode inventar falas da IA para desviar o chat. Montar o histórico a partir do banco (`plant_messages`), não do corpo da requisição. |
| C6 | **Disjuntor de custo global** | Guardar `ai_daily_cap` em `app_config` (ex.: 500 chamadas/dia no total). Passou, a IA pausa e o app avisa "Muita gente usando agora". Protege o bolso se viralizar ou se for atacado. |
| C7 | **Botão de pânico** | `app_config.ai_enabled = false` desliga a IA sem mexer no código. O app continua mostrando catálogo, conversas e lembretes. |
| C8 | **Limite de tamanho nos textos gravados** | `CHECK (length(content) <= 4000)` em `plant_messages`, e o mesmo nos campos de `plant_corrections` e `reminders`. Ninguém enche o banco com texto gigante. |
| C9 | **Limite de correções** | No máximo 30 por usuário por dia (política ou gatilho). |
| C10 | **Sair limpa o aparelho** | Apagar a inscrição de notificação e o `localStorage` do app no logout (B12). |
| C11 | **Revisar os 14 avisos do scanner de segurança** | Rodar o *Security scan* do Lovable e colar a lista. Pelo que vi, a maioria deve ser do A1 (funções `SECURITY DEFINER` executáveis por `anon`/`authenticated`), do `pg_net` instalado no schema `public` e das tabelas internas com RLS e sem política (`ai_usage`, `app_config`, `rate_limits`). Nas tabelas internas é **proposital**: só o servidor acessa. Para cada aviso, corrigir ou justificar por escrito. |
| C12 | **Registrar o custo de cada chamada** | Gravar `usage` (tokens) de cada chamada ao Gemini numa tabela `ai_calls (user_id, kind, model, input_tokens, output_tokens, ms, ok, created_at)`. Sem isso, não dá para saber quanto cada usuário custa (E1). |

---

# PARTE D — Legal e confiança (antes de publicar)

Você pede login com Google e recebe fotos. No Brasil, isso cai na **LGPD**.

## D1. Obrigatório

1. **Política de Privacidade** (`/privacidade`). Precisa dizer:
   - quais dados você guarda (e-mail, nome, foto do Google, fotos das plantas,
     conversas, lembretes);
   - **para quem as fotos vão** — Google (Gemini) e **Pl@ntNet, na França**
     (transferência internacional);
   - por quanto tempo guarda;
   - como a pessoa pede para apagar tudo;
   - um e-mail de contato.
2. **Termos de Uso** (`/termos`).
3. **Excluir conta e dados** dentro do app (página `/conta`). Apagar o usuário
   leva tudo junto por `ON DELETE CASCADE`. Conferir que **todas** as tabelas
   com `user_id` têm essa chave estrangeira com cascade. Não consegui conferir
   as restrições do banco: a ferramenta caiu. `ai_usage` é a suspeita principal.
4. **Links para os dois documentos** na tela de login e no rodapé.

## D2. Avisos de responsabilidade

1. **"A IA pode errar"** no resultado: "Identificação e cuidados gerados por
   IA. Em caso de dúvida, consulte um agrônomo ou viveirista."
2. **Agrotóxicos.** O catálogo recomenda tebuconazol, azoxistrobina e
   "inseticida sistêmico". Muitos desses produtos exigem **receituário
   agronômico** no Brasil. Preferir primeiro soluções caseiras e de venda livre,
   e escrever "procure um agrônomo" quando for defensivo químico. Colocar essa
   regra também no prompt do plano de cuidado.
3. **Toxicidade.** Costela-de-adão, por exemplo, é **tóxica para cães e gatos**,
   e o app não fala nada. Incluir **"Tóxica para pets/crianças?"** no plano de
   cuidado (F7).
4. Na palmeira, o texto diz **"QUEIME as folhas"**. Queimar resíduo é proibido
   em muitos municípios. Trocar por "descarte em saco fechado, separado do lixo
   comum e da compostagem".

---

# PARTE E — Dinheiro: não ficar no prejuízo

## E1. Medir antes de pôr preço

Hoje **ninguém sabe quanto custa uma identificação**. Com o C12 funcionando, 1–2
semanas de uso real respondem:
- quantos tokens gasta, em média, uma identificação (visão + plano de cuidado);
- quantas mensagens de chat um Pro manda por dia;
- quanto o **catálogo economiza** (planta já conhecida não gasta IA para o
  plano de cuidado).

A IA é cobrada do **saldo de IA do workspace** no Lovable. Com o plano grátis
do Lovable, esse saldo é pequeno. **Confira em Configurações → Uso / Cloud & AI
balance.**

## E2. Regras que já protegem o bolso

- **1 foto = 1 crédito** (B1)
- **Chat fora do grátis** (A5)
- **Teto global** de IA por dia (C6) e de Pl@ntNet (A12)
- **Cache pelo catálogo.** Já existe; fica mais forte com o A8, porque não entra
  lixo.
- **Limite grátis de 3 por mês.** Está bom para experimentar sem virar custo.

## E3. Cobrança (Stripe)

O conector **Stripe** aparecia ligado no workspace na última checagem (22/08).
Falta:
1. **Checkout** do plano Pro (mensal), a partir da página `/conta` e dos
   cartões Pro.
2. **Webhook** (`/api/public/stripe-webhook`, com **verificação da assinatura**
   do Stripe) que atualiza `profiles.plan`, `subscription_status` e
   `stripe_customer_id`.
3. **Portal do cliente** para cancelar e trocar cartão.
4. **Teste grátis com cartão?** Decidir. Pedir cartão no início reduz abuso e
   converte mais. Sem cartão atrai mais gente.
5. **Preço:** só depois do E1. A regra é custo médio de um Pro × 3, no mínimo.

---

# PARTE F — O que você pediu e ainda não foi feito

## F1. "Minhas plantas" — a base de tudo

Hoje a planta identificada **só existe na memória da tela**. Recarregou e não
abriu o chat? **Perdeu.**

- **Tabela `user_plants`:** `id, user_id, catalog_key, sci, name, nickname,
  photo_path, room, created_at`.
- **Botão "Salvar em Minhas plantas"** no resultado. Para o Pro, salvar
  automaticamente.
- **Aba "Minhas plantas"** na barra de baixo. Cada planta abre com a foto do
  usuário, o plano de cuidado, o chat, os lembretes e o diário (F3).
- O chat e os lembretes passam a ser **da planta do usuário**
  (`user_plant_id`), não da espécie. Duas samambaias são duas plantas.

## F2. Diagnóstico de planta doente

"Tirar foto de uma planta morrendo e o app dizer o que é e como consertar." A
tela já tem o espaço ("Problema detectado na foto"), mas **nunca é preenchido**.

- **Botão separado na home:** **"Minha planta está doente"**, além de
  "Identificar planta".
- **Endpoint `/api/diagnose-plant`**, com cota própria (`kind='diagnose'`) e
  **só Pro** (ou 1 por mês no grátis, como amostra).
- **Fluxo:** identificar a espécie (reusa o fluxo atual) → Gemini com a foto +
  a espécie → JSON validado:
  ```json
  {
    "saudavel": false,
    "problemas": [
      {
        "nome": "Excesso de rega",
        "confianca": 0.7,
        "sinais_na_foto": "...",
        "causa": "...",
        "o_que_fazer_hoje": ["..."],
        "o_que_fazer_na_semana": ["..."],
        "gravidade": "leve|moderada|grave"
      }
    ],
    "perguntas": ["Com que frequência você rega?", "Ela pega sol direto?"]
  }
  ```
- **Perguntas de volta.** Diagnóstico por foto é incerto. Mostrar as perguntas
  e refinar a resposta com o que a pessoa responder.
- **Gravidade "grave"** → "Procure um viveirista ou agrônomo" em destaque.
- **Nunca receitar defensivo químico sem o aviso do D2.**

## F3. Diário: uma foto por dia, com análise

"Todo dia tirar foto da planta para ir atualizando." Isso **existe no Emergent,
não no Smart Garden IA**.

- **Tabela `plant_journal`:** `id, user_plant_id, user_id, photo_path, note,
  ai_summary, health_score, created_at`.
- **Botão "Foto de hoje"** dentro de cada planta de "Minhas plantas".
- **Análise comparando com a foto anterior:** "folhas novas surgiram", "o
  amarelado aumentou", "está melhor que semana passada".
- **Linha do tempo** com as fotos e um gráfico simples de saúde.
- **Lembrete opcional** "Hora da foto da sua samambaia 📸".
- **Controle de custo:** análise por IA **1 por planta por dia**, só Pro. No
  grátis, guarda a foto sem análise.
- Depende do **B7** (Storage).

## F4. Chat que consulta fontes antes de responder

**Hoje o chat responde de memória.**

1. **Primeiro passo (barato e confiável):** antes de cada resposta, mandar ao
   Gemini:
   - o plano de cuidado da planta (do catálogo);
   - o resumo da Wikipédia;
   - a taxonomia do GBIF.

   Instrução: "responda com base nessas fontes; se não souber, diga que não
   sabe".
2. **Se o gateway do Lovable aceitar busca do Google** (*grounding*) no modelo
   Gemini, ligar para perguntas fora do plano de cuidado. **Confirmar no Lovable
   se o gateway oferece isso** antes de prometer.
3. **Mostrar as fontes** embaixo da resposta ("Fontes: Wikipédia, GBIF").

## F5. Teste grátis de 14 dias + pagamento

Itens **A4** e **E3**.

## F6. Memória com login

O banco já guarda conversas e lembretes **do Pro**. Falta:
- a tela mostrar isso (A3, A6);
- guardar a **foto** (B7);
- guardar as **plantas** (F1).

## F7. Mais informação no plano de cuidado

Acrescentar ao esquema do plano:
- `toxicidade`: pets e crianças;
- `luz`: sol pleno, meia-sombra ou sombra;
- `dificuldade`: fácil, média ou difícil;
- `epoca_de_adubar`, **no hemisfério sul**.

Gerar isso também para as 8 plantas do catálogo.

---

# PARTE G — Ideias novas para acrescentar

Ordenadas por valor ÷ esforço:

1. **Rega inteligente pelo clima.** A API **Open-Meteo** é grátis e não precisa
   de chave. Com a cidade da pessoa: "Choveu 12 mm ontem — pode pular a rega do
   girassol hoje." É o tipo de coisa que faz o app parecer mágico.
2. **Fotos de referência nas candidatas.** O Pl@ntNet devolve fotos de exemplo
   de cada espécie (`include-related-images=true`). Mostrar a foto ao lado de
   cada candidata faz a pessoa **acertar a escolha muito mais**. As imagens são
   **CC BY-SA**: mostrar o crédito.
3. **Mais de uma foto na identificação** (folha + flor). O Pl@ntNet aceita até 5
   fotos da mesma planta e acerta mais. "Adicionar outra foto" quando a
   confiança vier baixa.
4. **Compartilhar no WhatsApp.** "Olha minha costela-de-adão 🌿", com card
   bonito. Traz usuário novo de graça. (O Emergent tinha isso.)
5. **Apelido e cômodo:** "Samambaia da varanda", "Cacto do escritório".
6. **"Reportar erro neste cuidado"** no resultado. Vai para uma fila que você
   revisa, e o plano errado sai do catálogo.
7. **Painel do dono** (`/admin`, só seu e-mail):
   - usuários e quantos são Pro;
   - identificações por dia e custo estimado (C12);
   - correções mais comuns;
   - acerto do limite 0,55.
8. **Calibrar o limite 0,55 com dados reais.** Com as correções (`plant_corrections`),
   ver a partir de que confiança o Pl@ntNet costuma acertar, e ajustar.
9. **Gemini como "desempate".** Quando o Pl@ntNet vier abaixo de 0,55, mandar a
   foto ao Gemini com as 3 candidatas e perguntar qual bate melhor. Costuma
   acertar mais que cada um sozinho. Custa 1 chamada a mais, então só no Pro.
10. **Primeira abertura (3 telas):** o que o app faz, dica de foto boa, e o
    teste de 14 dias.
11. **Calendário do jardim:** o que fazer este mês (adubar, podar, trocar o
    vaso), para cada planta de "Minhas plantas".

---

# PARTE H — Emergent

O Emergent (`smart-plant-doc`) tem **diário, compartilhamento e painel admin**,
mas está **sem créditos** e duplica o produto. Manter dois apps é fazer tudo
duas vezes.

**Recomendação:** congelar o Emergent e usá-lo só como **referência** para o
F3 (diário), o G4 (compartilhar) e o G7 (admin) no Smart Garden IA. Não gastar
crédito lá.

---

# PARTE I — Ordem de execução

A conta do Lovable é **grátis**: os créditos acabam no meio de pedidos grandes,
como já aconteceu. Então **não mande tudo num prompt só**. Mande **uma fase por
vez**, e cada fase termina com o **build passando** e os **testes da fase**.

| Fase | O que entra | Por quê primeiro |
|---|---|---|
| **1 — Segurança e dinheiro** | A1, A2, A5, A8, B1, C2, C3, C6, C7, C12 | Fecha os buracos por onde você perde dinheiro. Quase tudo é servidor e SQL: pouco crédito. |
| **2 — Conta e planos** | A3, A4, A6, B2, B13 | Sem isso, seu tio não consegue nem entrar. |
| **3 — Identificação redonda** | A9, A10, A12, B8, B9, B11, G2 | O coração do app funcionando bem no celular. |
| **4 — Publicar** | A7, A11, B12, B14, D1, D2 | Publicar, notificação funcionando, textos legais. |
| **5 — Memória** | B7, F1, B3, B4, B5, B6 | Fotos e plantas salvas. |
| **6 — Pro de verdade** | E3, F2, F4, F7 | Cobrança e as funções que justificam pagar. |
| **7 — Diário e extras** | F3, G1, G3–G11 | O que faz o app ser especial. |

**Dicas para o prompt:**
- Comece cada fase com: **"Leia os arquivos X, Y, Z antes de mudar qualquer
  coisa."**
- Termine cada fase com: **"Rode o build e me mostre que passou. Depois rode os
  testes da seção 'Como testar' de cada item e me diga o resultado de cada um."**
- Para SQL: **"Crie uma migration nova. Não edite migrations antigas."**
- Para secrets: **"Nunca me peça para colar chave no chat; use o formulário de
  secrets."**

---

# PARTE J — Checklist antes de mostrar ao seu tio

Faça no **celular dele**, não no seu:

- [ ] Abrir o link publicado → a página aparece em português, com o nome e o ícone do app
- [ ] Tocar em "Entrar" → Google → volta logado, com selo **"Pro · teste até …"**
- [ ] Tirar foto de uma planta de casa → identifica em menos de 15 s
- [ ] Foto de uma planta difícil → aparecem as candidatas, com foto → escolher uma → o plano de cuidado abre
- [ ] "Não é essa planta?" → dá para achar a certa
- [ ] Abrir o chat → perguntar "posso colocar no sol?" → resposta coerente com a tela
- [ ] Criar lembrete **da planta identificada** para daqui a 5 min → a notificação chega (iPhone: com o app instalado na Tela de Início)
- [ ] Fechar tudo, abrir de novo → planta, foto, conversa e lembrete continuam lá
- [ ] Rodapé com Privacidade, Termos e crédito do Pl@ntNet
- [ ] Minha conta → Sair → entrar de novo → tudo continua lá

---

## Fontes consultadas

- [Pl@ntNet — Termos de uso da API](https://my.plantnet.org/terms_of_use)
- [Pl@ntNet — Preços e condições](https://my.plantnet.org/pricing)
- Código do projeto Lovable, commit `23a17d7`, e o banco de produção, em 27/09/2026.
