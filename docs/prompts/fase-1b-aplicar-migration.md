O banco voltou. Agora é terminar a Fase 1, que ficou pendente porque o banco estava pausado.

## 1. Aplique a migration da Fase 1

É a que você escreveu na mensagem anterior. Ela tem:
- os `REVOKE` / `GRANT`;
- o `ALTER DEFAULT PRIVILEGES`;
- `identify_sessions`, `ai_global_usage`, `ai_global_hit` e `ai_calls`;
- as chaves `ai_enabled`, `ai_daily_cap` e `plantnet_daily_cap` em `app_config`;
- a remoção de `ai_usage_hit` e `ai_usage_refund`.

**Eu aprovo a remoção dessas duas funções.** O código não usa mais nenhuma delas.

**Não mexa** em `cron_secret`.

## 2. Mostre o resultado desta consulta

```sql
SELECT p.proname,
       has_function_privilege('anon', p.oid, 'EXECUTE') anon,
       has_function_privilege('authenticated', p.oid, 'EXECUTE') authenticated
FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
WHERE n.nspname='public' AND p.prosecdef;
```

Esperado: `anon = false` em **todas**, e `authenticated = true` **só** em `user_plan`.

## 3. Mostre também

```sql
SELECT key FROM public.app_config ORDER BY key;
SELECT to_regclass('public.identify_sessions'), to_regclass('public.ai_global_usage'), to_regclass('public.ai_calls');
SELECT count(*) FROM pg_proc WHERE proname IN ('ai_usage_hit','ai_usage_refund');
```

Esperado:
- `app_config` com `ai_daily_cap`, `ai_enabled`, `cron_secret` e `plantnet_daily_cap`;
- as três tabelas existindo;
- `0` funções antigas.

## 4. Rode os testes da Fase 1 que dependiam do banco

1. Mandar `{ "chooseSci": "Planta Falsa Teste" }` para `/api/identify-plant` → 400, nada gravado em `plant_catalog`, nenhuma linha nova em `ai_calls`.
2. Token de conta anônima em `/api/identify-plant` → 401. Se o login anônimo já estiver desligado, diga e pule.
3. Uma identificação de verdade, com uma foto de planta comum. Se você não tiver como fazer isso com um usuário real, diga e pule: eu faço pelo celular. Conferir:
   - linha em `ai_usage` com `kind='identify'`;
   - linha em `ai_calls` com tokens;
   - contagem em `ai_global_usage`.
4. `UPDATE app_config SET value='false' WHERE key='ai_enabled'` → identificação responde 503 "manutenção" e a cota volta. **Depois volte para `'true'`.**

Me mostre o resultado de cada teste. **Não publique ainda.**
