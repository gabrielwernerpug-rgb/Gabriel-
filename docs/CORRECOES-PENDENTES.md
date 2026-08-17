# Checklist antes de publicar

Estado em **17/08**. Os dois bugs que bloqueavam a publicação foram corrigidos e
verificados. Restou **uma** pendência, e ela é de configuração, não de código.

---

## 🔴 Falta ligar a Lovable AI no workspace

No teste de ponta a ponta, a identificação por foto passou pela autenticação sem
erro, mas o gateway respondeu:

```
403 — Lovable AI is disabled for this workspace
```

Sem isso, o fluxo principal do app não funciona: a pessoa manda a foto e não
recebe identificação nenhuma.

**Ação:** ativar a Lovable AI em **Connectors**, no projeto do Lovable.

**Vale confirmar:** o teste rodou contra o servidor de desenvolvimento. A
mensagem fala em "workspace", o que sugere valer para produção também — mas
confirme com uma identificação real no preview depois de ativar, antes de
publicar.

---

## ✅ Resolvido — o cron do push tomava 401

O endpoint `/api/public/send-reminders` passou a exigir `x-cron-secret`, mas o
agendamento continuava mandando só `apikey`. Toda execução batia em 401 e
nenhuma notificação saía.

**Como foi corrigido:**

- O segredo foi gravado em `public.app_config` por **parâmetro** (via conexão
  direta com `psql`, usando bind de variável) — nunca literal no corpo da
  migration, nunca ecoado em log
- `cron.unschedule('send-watering-reminders')` seguido de reagendamento montando
  o header `x-cron-secret` a partir de `app_config`
- A migration **valida** que sobrou exatamente 1 job com esse nome, e falha com
  exceção se não sobrou — em vez de deixar dois disparando em paralelo
- `REVOKE ALL ON public.app_config FROM anon, authenticated` — a tabela tinha
  grants para `anon` que não deveriam existir

Manter o segredo em `app_config` (e não literal na migration) importa porque
migrations ficam versionadas no repositório do projeto.

---

## ✅ Resolvido — a primeira foto falhava com 401

`identify-plant` passou a exigir bearer token (para a cota por usuário), mas o
`fetch` lia `supabase.auth.getSession()`, que devolve `null` antes de a sessão
anônima existir. Em aba nova, a primeira identificação tomava 401.

**Como foi corrigido** — em `src/lib/garden-store.ts`, uma função `validSession()`
central:

```ts
async function validSession() {
  const { data } = await supabase.auth.getSession();
  const session = data.session;
  if (session) {
    const expiresAt = (session.expires_at ?? 0) * 1000;
    const stillValid = expiresAt - Date.now() > 60_000;
    if (stillValid) return session;
    const { data: refreshed } = await supabase.auth.refreshSession();
    if (refreshed.session) return refreshed.session;
  }
  const { data: anon, error } = await supabase.auth.signInAnonymously();
  ...
}
```

`ensureSession()` e o novo `ensureAccessToken()` passam os dois por ela, e
`identifyPlantFromPhoto` faz `await ensureAccessToken()` antes do fetch.

A folga de 60 segundos evita o caso chato: token que ainda é válido na hora da
checagem e expira no meio da requisição.

**Verificado:** teste automatizado em aba limpa, sem sessão — a foto saiu já com
token válido, **nenhum 401**.

---

## Efeitos colaterais conhecidos (não bloqueiam)

- **Sessão anônima perdida = histórico perdido.** Se o refresh token expirar ou
  for revogado, `validSession()` cria uma sessão anônima **nova**. As conversas e
  lembretes do usuário anterior ficam inalcançáveis. Como a conta anônima não tem
  credencial para recuperar, não há alternativa melhor — mas hoje isso acontece
  em silêncio. O ideal seria avisar a pessoa, em vez de ela achar que o app
  apagou tudo.
- **`chat-plant` não tem cota por usuário.** A identificação ganhou limite de 20
  por dia por usuário, mas o chat continua só com o limite por IP. Como o chat
  também chama o modelo, dá para gastar crédito de API por ali sem esbarrar em
  cota nenhuma. Vale alinhar os dois.
