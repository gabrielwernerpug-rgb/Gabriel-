Um problema só: **não dá para criar lembrete da planta que a pessoa acabou de fotografar.** O modal só lista as 8 plantas de `PLANT_KEYS`.

O banco já cuida de duas coisas:
- lembrete criado depois do horário do dia não dispara mais na hora;
- lembrete de quem saiu do Pro fica pausado.

Faça:

1. Na tela de resultado (Pro), botão **"Criar lembrete de rega"**. Ele abre o modal já preenchido com:
   - a planta e a foto;
   - a frequência, tirada de `water.freq` (o primeiro número em dias, ou 2 se não achar);
   - a quantidade, de `water.amount`.
2. O select do modal lista também as plantas com conversa e as identificadas nesta sessão.
3. O `plant_key` do lembrete é a mesma chave do chat, para o clique na notificação (`/?plant=<chave>`) abrir a planta certa.
4. Troque o texto "A cada 15 dias" (value 14) por **"A cada 14 dias"**. O banco rega a cada 14.
5. **Notificação** (`send-reminders.ts`):
   - título **"💧 Hora de regar: ${nome}"** (hoje é "sua ${nome}", e fica "sua Cacto");
   - `VAPID_SUBJECT` = `mailto:` + o `CONTACT_EMAIL`.
6. Na tela de lembretes do usuário grátis: "Seus lembretes estão pausados — voltam quando você tiver o Pro".

No fim: build limpo e o que mudou.
