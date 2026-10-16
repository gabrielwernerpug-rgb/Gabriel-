Fase 4 de 4: lembretes, memória do chat e fotos guardadas. Com esta fase, o app fica pronto para mostrar.

**Pré-requisito:** Fases 1 a 3 aplicadas e o app publicado. Se não estiver, pare e me avise.

**Regras desta leva**
- Leia `SmartGarden.tsx`, `garden-store.ts`, `send-reminders.ts`, `push.ts` e a função `claim_due_reminders` antes de mudar.
- SQL só em migration nova. Função nova nasce com `REVOKE ALL ... FROM PUBLIC, anon, authenticated`.
- No fim: build limpo e o resultado do teste de cada item.

---

## 1. Lembrete da planta que acabou de ser identificada

Hoje o modal de lembrete só lista as 8 plantas de `PLANT_KEYS`. **Não dá para criar lembrete da planta que a pessoa acabou de fotografar.**

- Na tela de resultado (Pro), botão **"Criar lembrete de rega"**. Ele abre o modal já preenchido com:
  - a planta e a foto;
  - a frequência, tirada de `water.freq` (o primeiro número em dias, ou "A cada 2 dias" se não achar);
  - a quantidade, de `water.amount`.
- O select do modal lista também as plantas com conversa e as identificadas nesta sessão, não só as 8 do catálogo.
- O `plant_key` do lembrete é a mesma chave usada no chat, e o clique na notificação (`/?plant=<chave>`) abre a planta certa.

## 2. "A cada 15 dias" que rega a cada 14

`<option value="14">A cada 15 dias</option>` e `freqLabels["14"]`: o banco rega a cada **14**. Troque o texto para **"A cada 14 dias"**.

## 3. Lembrete criado depois do horário dispara na hora

Em `claim_due_reminders`, quem cria às 10:00 um lembrete das 08:00 recebe a notificação no ciclo seguinte (`last_sent_at` vazio).

Corrija no `insertReminder`: se o horário de hoje, no fuso do lembrete, já passou, grave `last_sent_at = now()`. O primeiro aviso fica para o próximo ciclo.

## 4. Quem perdeu o Pro

Lembrete de quem saiu do Pro (fim do teste) continua sendo enviado. Em `claim_due_reminders`, só pegue lembretes de quem `user_plan(r.user_id) = 'pro'`.

A função roda como `service_role`, então `auth.uid()` é nulo e `user_plan` devolve o plano real.

Na tela de lembretes do usuário grátis, mostre "Seus lembretes estão pausados — eles voltam quando você tiver o Pro".

## 5. Texto da notificação

Hoje é "Hora de regar sua ${nome}", e fica errado em nome masculino ("sua Cacto"). Troque por:
- título: **"💧 Hora de regar: ${nome}"**;
- corpo: **"${quantidade} de água agora."**

`VAPID_SUBJECT` cai em `mailto:notificacoes@smartgarden.app`, um domínio que não é nosso. Use o mesmo `CONTACT_EMAIL` da Fase 3, no formato `mailto:`.

## 6. Histórico do chat carregando as mensagens mais antigas

`loadChats` busca `order("created_at", { ascending: true }).limit(600)`, ou seja, as **600 mais antigas**. Quem conversa muito perde as recentes ao recarregar.

Busque as **50 mais recentes de cada conversa**: ordem decrescente por conversa, depois inverta para mostrar.

## 7. A foto do usuário some ao recarregar

`sanitizePlantForDb` troca a foto por uma imagem genérica do Unsplash (`FALLBACK_IMG`). A pessoa fotografa a planta dela e, no dia seguinte, aparece outra planta.

**a) Storage**
- Bucket **`plant-photos`**, **privado**, limite de 2 MB, só `image/jpeg`.
- Políticas em `storage.objects`: cada usuário só lê, grava e apaga na pasta `{auth.uid()}/...`.

**b) Ao identificar** (usuário logado), suba a foto **já comprimida** para `{user_id}/{uuid}.jpg`.

**c) Gravar e mostrar**
- Em `plant_chats.plant` e `reminders.img`, grave o **caminho**, não a URL.
- Para mostrar, gere URL assinada de 1 hora.
- Tire `FALLBACK_IMG` e `stripDataUrl` do caminho normal. Imagem genérica só se a foto não existir mais.

**d)** Ao excluir a conta (Fase 2), apague também a pasta do usuário no bucket.

## 8. Fotos do catálogo

Samambaia, costela-de-adão, cacto, girassol e rosa, e a foto grande da home (`HERO_IMG`), ainda vêm por link direto do Unsplash.

Se eu anexar as fotos nesta mensagem, use-as. Senão, gere fotos no mesmo estilo de `plant-orchid.jpg`:
- fundo claro e limpo;
- luz natural;
- planta saudável e centralizada;
- sem texto.

Salve em `src/assets/` e importe em `plants.ts`, como a orquídea já faz.

## 9. Teste final de ponta a ponta

No app publicado, com uma conta Google de teste:
1. Entrar → selo "Pro · teste até …".
2. Foto de uma planta comum → resultado com a foto da pessoa, a procedência e o aviso de IA.
3. Foto difícil → candidatas com foto de referência → escolher uma → plano de cuidado.
4. Chat → resposta coerente com o plano de cuidado.
5. Criar lembrete **da planta identificada** para daqui a 5 min → a notificação chega.
6. Recarregar → planta, foto, conversa e lembrete continuam lá.
7. Sair → entrar de novo → tudo continua.
8. `/conta` → mostra o uso do mês.

Me diga o resultado de cada passo.
