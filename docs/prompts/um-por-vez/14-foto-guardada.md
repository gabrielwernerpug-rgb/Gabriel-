Um problema só: **a foto da pessoa some ao recarregar.** `sanitizePlantForDb` troca a foto por uma imagem genérica do Unsplash (`FALLBACK_IMG`). A pessoa fotografa a planta dela e, no dia seguinte, aparece outra planta.

Faça:

1. Bucket **`plant-photos`**, **privado**, limite de 2 MB, só `image/jpeg`.
2. Políticas em `storage.objects`: cada usuário só lê, grava e apaga na pasta `{auth.uid()}/...`.
3. Ao identificar, com o usuário logado, suba a foto **já comprimida** para `{user_id}/{uuid}.jpg`.
4. Em `plant_chats.plant` e `reminders.img`, grave o **caminho**, não a URL.
5. Para mostrar, gere URL assinada de 1 hora.
6. Tire `FALLBACK_IMG` e `stripDataUrl` do caminho normal. Imagem genérica só se a foto não existir mais.
7. Ao excluir a conta, apague também a pasta do usuário no bucket.

Lembre: o banco não dá mais `EXECUTE` automático em função nova. Dê `GRANT` explícito no que criar.

No fim: build limpo e o que mudou.
