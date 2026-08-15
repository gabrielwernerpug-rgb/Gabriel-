# Correções pendentes — aplicar antes de publicar

> ⚠️ **O app está quebrado em duas frentes neste momento** (commit `32fa1db4`).
> Não publique antes de aplicar as duas correções abaixo.

As duas foram diagnosticadas e confirmadas no código pelo próprio agente do
Lovable, mas os créditos do workspace acabaram antes de ele aplicar. **Nenhuma
das duas precisa de crédito de agente** — dá para aplicar à mão, como está
descrito aqui.

---

## 1. O push está fora do ar — o cron toma 401

**O que aconteceu:** o endpoint `/api/public/send-reminders` passou a exigir o
header `x-cron-secret` (correção de segurança, commit `32fa1db4`), mas o
agendamento criado lá atrás na migration `20260812215847` **continua mandando só
o header `apikey`**. Toda execução do cron bate em 401 e **nenhuma notificação é
entregue**. A tabela `app_config` foi criada para guardar o segredo, mas ficou
vazia e ninguém lê dela.

**Onde aplicar:** SQL Editor do Supabase (não precisa do agente).

Troque `VALOR_DO_CRON_SECRET` pelo mesmo valor que está no secret `CRON_SECRET`
do projeto — os dois lados têm que bater exatamente.

```sql
-- 1. Guardar o segredo onde o cron consegue ler.
--    app_config tem RLS ligada e nenhuma policy: só o service_role enxerga.
INSERT INTO public.app_config (key, value)
VALUES ('cron_secret', 'VALOR_DO_CRON_SECRET')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

-- 2. Remover o agendamento antigo (o que manda apikey).
SELECT cron.unschedule('send-watering-reminders');

-- 3. Reagendar montando o header a partir do app_config.
SELECT cron.schedule(
  'send-watering-reminders',
  '*/5 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://project--ae9ae530-ced6-41c2-a9d9-8f939661629d.lovable.app/api/public/send-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (SELECT value FROM public.app_config WHERE key = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $$
);

-- 4. Conferir que sobrou exatamente UM job com esse nome.
SELECT jobid, jobname, schedule FROM cron.job
WHERE jobname = 'send-watering-reminders';
```

O passo 4 importa: se o `unschedule` falhar silenciosamente, ficam dois jobs
disparando em paralelo.

**Como verificar que funcionou:** depois de alguns minutos, confira o retorno das
execuções do cron. Se ainda vier 401, o valor em `app_config` não bate com o
secret `CRON_SECRET`.

---

## 2. A primeira identificação por foto falha com 401

**O que aconteceu:** `identify-plant` passou a exigir um bearer token válido do
Supabase (`userIdFromRequest`), para poder aplicar a cota diária por usuário.
Mas o `fetch` em `identifyPlantFromPhoto` (perto da **linha 414** de
`src/components/smart-garden/SmartGarden.tsx`) monta o header com
`supabase.auth.getSession()`, que devolve `null` enquanto a sessão anônima ainda
não existe. O `ensureSession()` — que é quem faz o `signInAnonymously()` — só
roda em outro caminho, perto da linha 334.

**Efeito para quem usa:** numa aba nova, sem sessão, a primeira foto sai sem o
header `Authorization` e recebe **401 "Sessão inválida"**. Só funciona na segunda
tentativa. É o primeiro contato de todo usuário novo com o app.

**Onde aplicar:** editor de código do Lovable (não precisa do agente).

Em `identifyPlantFromPhoto`, antes de montar o `fetch`, troque a leitura passiva
da sessão por uma garantia de sessão:

- **Hoje:** pega o token de `supabase.auth.getSession()` — que pode ser `null`.
- **Deve ser:** `await ensureSession()` (de `@/lib/garden-store`) antes do fetch,
  e só então ler o token para montar o header `Authorization: Bearer <token>`.

`ensureSession()` já devolve a sessão existente quando há uma, e faz
`signInAnonymously()` quando não há — então a troca é segura e não cria sessão
duplicada.

**Cuidado a mais:** se alguém já tinha uma sessão anônima antiga e o token dela
expirou, `ensureSession()` precisa **renovar** em vez de devolver um token morto.
Do jeito que está escrito hoje ele faz `getSession()` e retorna o `user.id` se
existir sessão — sem checar validade. Vale confirmar esse caso, senão usuários
antigos tomam 401 sem entender por quê.

**Como verificar que funcionou:** abrir o app numa aba anônima (sem sessão
nenhuma), mandar uma foto e confirmar que identifica **de primeira**, sem 401.

---

## Depois das duas

Aí sim o app fica publicável. O que já está resolvido e verificado:

- Endpoint de push autenticado com segredo compartilhado, comparação em tempo
  constante, só POST, resposta sem contagens
- RLS de `plant_messages` amarrando o `chat_id` ao dono no INSERT
- Cota diária de 20 identificações por usuário, com incremento atômico e refund
  em todos os caminhos de erro
- `EXECUTE` revogado de `anon`/`authenticated` nas funções privilegiadas
- Push com `FOR UPDATE SKIP LOCKED`, fuso por lembrete e limpeza de assinatura
  morta em 404/410

Continua em aberto, sem bloquear a publicação: a foto do usuário sumir no reload
(P1 do [roadmap](ROADMAP.md)) e as 5 fotos de planta ainda não aplicadas no app
(P4).
