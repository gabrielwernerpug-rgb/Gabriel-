Um problema só: **as correções de banco de 16/10 foram aplicadas direto no banco de produção e não existem como arquivo de migration.** Se alguém recriar o projeto a partir das migrations, elas somem.

O SQL está abaixo. **Tudo é idempotente.** Crie **uma** migration com este conteúdo, exatamente como está, e rode. Como já está aplicado, rodar de novo não muda nada.

Depois, confira que:
- `has_function_privilege('anon', ...)` é falso em todas as funções `SECURITY DEFINER` do schema `public`;
- `ai_usage_hit` e `ai_usage_refund` não existem mais.

(cole aqui o conteúdo de docs/sql/2026-10-16-correcoes.sql)
