Um problema só: **no iPhone, a notificação de rega nunca vai chegar.** No iPhone, notificação de site só funciona com o app **instalado na Tela de Início**, e isso exige um manifesto que o projeto não tem. Hoje `/manifest.json` dá 404.

Faça:

1. Crie `public/manifest.webmanifest`:
   - nome "Smart Garden IA" e nome curto "Smart Garden";
   - ícones 192 e 512 PNG, gerados a partir do favicon;
   - `display: standalone`;
   - cores verdes em `theme_color` e `background_color`.
2. Acrescente `apple-touch-icon` (180 px), `<meta name="theme-color">` e o link do manifesto no `<head>`.
3. No primeiro lembrete, se for iPhone ou iPad e o app **não** estiver instalado (`navigator.standalone !== true` e sem `display-mode: standalone`), mostre:
   > Para receber o aviso de rega no iPhone: toque em **Compartilhar** → **Adicionar à Tela de Início** e abra o Smart Garden por lá.

No fim: build limpo e o que mudou.
