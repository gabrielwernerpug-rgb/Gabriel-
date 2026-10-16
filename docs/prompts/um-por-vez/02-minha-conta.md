Um problema só: **não existe página "Minha conta"**, e não dá para apagar a conta (a LGPD exige).

O banco já está pronto: a função `my_usage()` (só para usuário logado) devolve `plan`, `subscription_status`, `trial_ends_at`, `identify_month`, `identify_today` e `chat_today`. O teste grátis de 14 dias já é dado automaticamente no cadastro, no banco.

Faça:

1. **Página `/conta`**, aberta pelo menu do cabeçalho:
   - plano atual: **Grátis**, **Pro** ou **Pro · teste até DD/MM** (com os dias restantes);
   - uso do mês: "X de 3 identificações" no grátis, "X hoje" no Pro (limites de `PLAN_LIMITS`);
   - texto "Assinatura Pro em breve" (ainda não há cobrança);
   - botão **Sair**;
   - botão **Excluir minha conta e meus dados**, com confirmação digitando EXCLUIR.
2. **Excluir conta:** server function com `requireSupabaseAuth` que chama `supabaseAdmin.auth.admin.deleteUser(userId)`. O banco apaga tudo em cascata. Depois, sair e voltar para a home.
3. **Sair limpa o aparelho:** antes do `signOut`, cancele a inscrição de notificação deste navegador (`pushManager.getSubscription()` → `unsubscribe()`) e apague a linha em `push_subscriptions`. Em celular compartilhado, o próximo usuário não pode receber os avisos do anterior.
4. Em `api-guard.ts`, `getUserPlan()` passa a usar `supabaseAdmin.rpc('user_plan', { _user_id })`, que já considera a data do teste, em vez de ler a coluna `plan`.
5. Em `identify-plant.ts`, troque a mensagem do limite grátis ("o plano Pro… chega em breve") por: "Você usou as 3 identificações grátis deste mês. Elas voltam no dia 1º."

No fim: build limpo e o que mudou em cada arquivo.
