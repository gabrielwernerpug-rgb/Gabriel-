Fase 2 de 4: conta, plano e tela de resultado.

**Pré-requisito:** a migration da Fase 1 já foi aplicada (Fase 1b). Se ainda não foi, pare e me avise.

Não publique nada nesta fase. Hoje o app exige login, mas não tem botão de entrar em lugar nenhum. O teste grátis de 14 dias não existe. E a tela finge que salvou coisas que o banco recusou.

**Regras desta leva**
- Leia `SmartGarden.tsx`, `garden-store.ts`, `api-guard.ts`, `auth.tsx` e `__root.tsx` antes de mudar.
- SQL só em migration nova. Toda função nova nasce com `REVOKE ALL ... FROM PUBLIC, anon, authenticated` e com GRANT explícito só para quem precisa.
- No fim: build limpo, e o resultado do teste de cada item.

---

## 1. Teste grátis de 14 dias (não existe hoje)

Hoje nenhum gatilho cria o perfil no cadastro. Nada preenche `trial_ends_at`. E nem `user_plan()` nem `getUserPlan()` olham a data. Um Pro de teste nunca expiraria.

**a) Tabela `trial_claims`**
- Colunas: `email_hash text primary key`, `created_at timestamptz default now()`.
- RLS ligada, sem políticas.

**b) Gatilho `AFTER INSERT ON auth.users`** (função `SECURITY DEFINER`, `search_path = public, extensions`)
- Se `NEW.is_anonymous` → só cria o perfil `free`.
- Senão, calcula `encode(extensions.digest(lower(NEW.email), 'sha256'), 'hex')`:
  - se **não existe** em `trial_claims` → grava o hash e cria o perfil `plan='pro'`, `subscription_status='trialing'`, `trial_ends_at = now() + interval '14 days'`;
  - se **já existe** → perfil `free`. Quem apaga a conta e cria de novo não ganha outro teste.
- `ON CONFLICT (user_id) DO NOTHING`.

**c) `user_plan()` vira a única regra de "é Pro?"**
```sql
SELECT CASE
  WHEN auth.uid() IS NOT NULL AND auth.uid() <> _user_id THEN 'free'
  WHEN p.plan = 'pro' AND p.subscription_status IN ('active','manual') THEN 'pro'
  WHEN p.plan = 'pro' AND p.subscription_status = 'trialing' AND p.trial_ends_at > now() THEN 'pro'
  ELSE 'free' END
FROM public.profiles p WHERE p.user_id = _user_id
```
Com `COALESCE` para `'free'` quando não houver perfil. Mantenha as permissões que a Fase 1 deixou.

**d) `getUserPlan()` em `api-guard.ts`**
- Passa a chamar `supabaseAdmin.rpc('user_plan', { _user_id: userId })` em vez de ler a coluna.
- Se o perfil não existir, continua criando `free`.

**e) Texto do limite grátis**
- Troque "o plano Pro… chega em breve".
- Por: "Você usou as 3 identificações grátis deste mês. Elas voltam no dia 1º."

**Teste**
- Conta Google nova → perfil `pro/trialing` com 14 dias.
- `UPDATE profiles SET trial_ends_at = now() - interval '1 day'` nessa conta → `user_plan` devolve `free`.

## 2. Entrar, sair e "Minha conta"

`loadAccount()` e `signOut()` existem em `garden-store.ts`, mas nenhuma tela usa. Não há como chegar em `/auth` sem digitar o endereço.

**a) Cabeçalho fixo** em todas as páginas do app
- Deslogado: botão **Entrar**.
- Logado: foto do Google + selo do plano (**Grátis**, **Pro** ou **Pro · teste até DD/MM**) + menu com **Minha conta** e **Sair**.

**b) Login antes da câmera**
- Tocou em "Abrir câmera ou galeria" sem estar logado? Abre um aviso "Entre com o Google para identificar sua planta", com o botão, **antes** de escolher a foto.
- Qualquer 401 vira esse mesmo aviso, nunca só texto.

**c) Voltar para onde estava**
- Guarde a rota atual em `sessionStorage` antes do login.
- Em `/auth`, depois de entrar, volte para ela.

**d) Página `/conta`**
- Plano e dias restantes de teste.
- Uso do mês: crie a função `my_usage()` (`SECURITY DEFINER`, usa `auth.uid()`, `GRANT` só para `authenticated`). Ela devolve identificações do mês e mensagens de chat de hoje.
- Botão **Sair**.
- Botão **Excluir minha conta e meus dados**, com confirmação digitando EXCLUIR. Use uma server function com `requireSupabaseAuth` + `supabaseAdmin.auth.admin.deleteUser(userId)`.
  - Antes, confira que **todas** as tabelas com `user_id` têm chave estrangeira para `auth.users` com `ON DELETE CASCADE`: `ai_usage`, `ai_calls`, `identify_sessions`, `profiles`, `plant_chats`, `plant_messages`, `reminders`, `push_subscriptions`, `plant_corrections`.
  - Onde faltar, acrescente. Em `ai_calls`, `ON DELETE SET NULL` também serve.

**e) Sair limpa o aparelho**
- Antes do `signOut`, cancele a inscrição de notificação deste navegador (`pushManager.getSubscription()` → `unsubscribe()`) e apague a linha em `push_subscriptions`.
- Em celular compartilhado, o próximo usuário não pode receber os avisos do anterior.

## 3. A tela não pode fingir que salvou

O banco só deixa gravar conversa, mensagem e lembrete para Pro. Mas a tela mostra "Continuar no chat" para todo mundo e cria o lembrete na hora (`setReminders` antes de salvar). Quando o banco recusa, só aparece no console, e no recarregar tudo some.

- Carregue a conta e o plano ao abrir o app e guarde num estado.
- Usuário grátis:
  - no lugar do chat, cartão "Converse com a IA sobre sua planta — recurso do plano Pro";
  - no lugar dos lembretes, cartão "Lembretes de rega no celular — recurso do plano Pro";
  - ainda não há cobrança, então o botão leva a `/conta`, onde está escrito "Assinatura em breve".
- Usuário Pro: se `insertReminder`, `ensureChat` ou `saveMessage` falhar, **desfaça na tela** e avise ("Não consegui salvar. Tente de novo.").

## 4. Tela de resultado sem plano de cuidado

Quando a planta vem do GBIF/Wikipédia (`careAvailable: false`), o `ResultBody` desenha todos os cartões vazios. O tipo `Plant` do frontend nem tem `careAvailable`, `summary`, `sourceLabel` ou `sourceUrl`.

- Acrescente esses campos (e `taxonomy`) ao tipo `Plant`, todos opcionais.
- `careAvailable === false`:
  - não desenhe os cartões de cuidado;
  - mostre "Identificamos a espécie, mas ainda não temos um plano de cuidado confiável para ela", o `summary`, o link da fonte e o botão **Tentar gerar o plano de cuidado**;
  - o botão chama a API com `correctKey` se a planta estiver no catálogo; senão, mostra só o aviso.
- **Sempre mostre a procedência** no resultado. Exemplo: "Identificado por Pl@ntNet · Cuidados escritos por IA".

## 5. Confiança inventada

- As 8 plantas de `plants.ts` têm "97% de confiança" fixo. Abrindo pelo catálogo, mostre **"Do catálogo"**.
- Tire o falso "Analisando sua planta… A IA está identificando" de 800 ms em `startAnalysis`. Planta do catálogo abre direto.

## 6. Cara de app genérico

Em `__root.tsx`:
- Hoje está `title "Lovable App"`, `description "Lovable Generated Project"`, `author "Lovable"`, `twitter:site "@Lovable"` e `<html lang="en">`.
- Troque por: **Smart Garden IA**, descrição em português e `lang="pt-BR"`.
- A página 404 e a de erro também em português.
- Crie um favicon SVG com o logo do app (o broto verde que já existe em `IconLogo`).
- Crie uma imagem de compartilhamento 1200×630 para o `og:image` (fundo verde, logo e "Smart Garden IA — identifique sua planta pela foto").

## 7. Ajuste pequeno da Fase 1

No modo `identifyId`, a sessão é marcada como usada **antes** do `careForSpecies`. Se o Gemini falhar ou o disjuntor recusar, a pessoa perde a escolha e precisa mandar a foto de novo, pagando outra identificação.

Corrija: em falha técnica do `careForSpecies` nesse modo, volte `used_at` para `null`, para ela poder tocar de novo na candidata.

---

Quando terminar: build limpo, e o resultado do teste de cada item. Os testes que dependem do banco ficam marcados como "aguardando o banco".
