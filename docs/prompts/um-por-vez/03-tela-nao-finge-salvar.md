Um problema só: **a tela finge que salvou coisas que o banco recusou.**

O banco só deixa gravar conversa, mensagem e lembrete para quem é **Pro**. Mas:
- "Continuar no chat" aparece para todo mundo;
- o lembrete aparece criado na hora (`setReminders` antes de salvar) e, quando o banco recusa, o erro só vai para o console;
- no recarregar, tudo some, e a pessoa acha que o app perdeu os dados dela.

Faça:

1. Carregue a conta (`loadAccount`) ao abrir o app e guarde o plano num estado.
2. **Grátis:**
   - no lugar do chat, cartão "Converse com a IA sobre sua planta — recurso do plano Pro";
   - no lugar dos lembretes, cartão "Lembretes de rega no celular — recurso do plano Pro";
   - o botão dos dois cartões leva a `/conta`.
3. **Pro:** se `insertReminder`, `ensureChat` ou `saveMessage` falhar, **desfaça na tela** e avise: "Não consegui salvar. Tente de novo."
4. A resposta 403 `pro_required` do chat também mostra o cartão Pro.

No fim: build limpo e o que mudou.
