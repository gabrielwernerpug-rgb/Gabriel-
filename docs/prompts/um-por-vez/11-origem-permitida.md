Um problema só: **`isAllowedOrigin` aceita qualquer `*.lovable.app` e `*.lovableproject.com`**, ou seja, também os apps de outras pessoas.

Faça (`src/lib/api-guard.ts`):

1. Aceite só:
   - a prévia deste projeto (`id-preview--ae9ae530-ced6-41c2-a9d9-8f939661629d.lovable.app` e o domínio `lovableproject.com` deste projeto);
   - o endereço publicado deste projeto;
   - `localhost`;
   - o que estiver em `ALLOWED_ORIGIN_HOSTS`.
2. Quando recusar uma origem, registre no log **uma vez por hostname**, para eu descobrir se esqueci de configurar um domínio.
3. Escreva num comentário como adicionar um domínio próprio.

No fim: build limpo e o que mudou.
