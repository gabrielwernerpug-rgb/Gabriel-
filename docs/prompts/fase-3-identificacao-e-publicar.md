Fase 3 de 4: identificação redonda, textos legais e publicação.

**Pré-requisito:** Fases 1, 1b e 2 aplicadas e testadas. Se não estiverem, pare e me avise.

**Regras desta leva**
- Leia `SmartGarden.tsx`, `identify-plant.ts`, `plant-sources.ts`, `plantas.tsx`, `catalog.ts`, `push.ts` e `__root.tsx` antes de mudar.
- SQL só em migration nova. Função nova nasce com `REVOKE ALL ... FROM PUBLIC, anon, authenticated`.
- No fim: build limpo e o resultado do teste de cada item.

---

## 1. Fotos de referência nas candidatas

Quando a confiança vem baixa, a pessoa escolhe entre 3 nomes científicos que ela não conhece. Com uma foto de exemplo ao lado, ela acerta muito mais.

- **Pl@ntNet:** na chamada, acrescente `include-related-images=true`. Para cada resultado, guarde uma imagem pequena (`images[0].url.m` ou `.s`), o autor e a licença, junto da candidata em `identify_sessions` e na resposta.
- **Candidatas do Gemini:** use a miniatura do `wikipediaSummary` da espécie, se houver.
- **Na tela:** foto pequena ao lado de cada candidata. Embaixo da lista, o crédito: "Fotos de referência: Pl@ntNet (CC BY-SA)".
- **Registro no log:** o Pl@ntNet devolve quantas identificações restam no dia (campo `remainingIdentificationRequests`; confira o nome no retorno real). Registre no log do servidor.

## 2. Crédito obrigatório do Pl@ntNet

Os termos do Pl@ntNet pedem atribuição. Coloque um rodapé discreto em todas as páginas:

> Identificação de espécies com a tecnologia [Pl@ntNet](https://my.plantnet.org/)

Inclua também links para **Privacidade** e **Termos** (item 6).

## 3. "Todas as plantas" de verdade

Em `plantas.tsx` e `catalog.ts`:
- **Cada card abre a planta.** Use a mesma tela de resultado. Se não tiver plano de cuidado, cai no aviso da Fase 2.
- **Busca robusta:** antes de montar o `.or(...)`, tire do termo vírgula, parênteses, ponto e `%`. Hoje "rosa, vermelha" quebra a consulta e mostra "Nada encontrado".
- **Paginação:** botão "Carregar mais" de 50 em 50, no lugar do limite fixo de 200.

## 4. "Não é essa planta?" sem beco sem saída

Se a busca no catálogo não achar nada, mostre dois botões:
- **Tentar com outra foto**, com a dica: "Fotografe a flor ou o fruto, de perto e com boa luz". Ele volta para a home já com o seletor em "Flor".
- **Cancelar**.

Acrescente também **"Casca/tronco"** (`bark`) ao seletor "O que está na foto?". O servidor já aceita.

## 5. Nada de carregamento infinito

- Coloque `AbortController` de **60 s** no fetch da identificação e no do chat.
- Na tela "Analisando sua planta…":
  - botão **Cancelar**;
  - depois de 15 s, a frase "Está demorando mais que o normal…".
- Estouro de tempo → "A análise demorou demais. Tente de novo." A cota volta pelo caminho de falha técnica que já existe.

## 6. Privacidade, termos e avisos

O app faz login com Google e recebe fotos, então cai na LGPD.

**a) Página `/privacidade`** em português simples. Deve dizer:
- quais dados guardamos: e-mail, nome e foto do Google, conversas, lembretes e uso do app;
- que **as fotos das plantas são enviadas ao Google (Gemini) e ao Pl@ntNet, na França**, para identificação. O Pl@ntNet diz que não guarda a foto, só o histórico da consulta;
- que a foto é comprimida e **sem localização GPS** antes de sair do celular;
- como apagar tudo: botão em `/conta`;
- um campo de contato. Peça o e-mail ao dono pelo formulário de secret `CONTACT_EMAIL`, sem pedir no chat, e mostre esse valor.

**b) Página `/termos`.** O app é informativo, a IA pode errar, e não substitui agrônomo ou viveirista.

**c) Links** para as duas páginas na tela de login e no rodapé.

**d) Aviso no resultado**, discreto:
> Identificação e cuidados gerados por IA. Em caso de dúvida, consulte um agrônomo ou viveirista.

**e) Toxicidade**
- Acrescente ao schema do plano de cuidado um campo **opcional** `toxicidade: { pets: "sim"|"não"|"incerto", criancas: "sim"|"não"|"incerto", nota: string }`. Opcional para não invalidar o catálogo antigo.
- Peça esse campo no prompt.
- Mostre em destaque quando for "sim".
- Preencha à mão nas 8 plantas de `plants.ts`: a costela-de-adão é tóxica para cães e gatos.

**f) `plants.ts`**
- Na palmeira, troque "Remova e QUEIME as folhas afetadas" por "Remova as folhas afetadas e descarte em saco fechado, separado do lixo comum e da compostagem". Queimar resíduo é proibido em muitos municípios.
- Onde o texto citar fungicida ou inseticida **sistêmico**, acrescente "(consulte um agrônomo; pode exigir receituário)".

## 7. App instalável (e notificação no iPhone)

No iPhone, notificação de site **só funciona se o app estiver instalado na Tela de Início**, e isso exige um manifesto.

- Crie `public/manifest.webmanifest`:
  - nome "Smart Garden IA" e nome curto "Smart Garden";
  - ícones 192 e 512 PNG, gerados a partir do favicon da Fase 2;
  - `display: standalone`;
  - `theme_color` e `background_color` verdes.
- Acrescente `apple-touch-icon` (180 px), `<meta name="theme-color">` e o link do manifesto no `<head>`.
- No primeiro lembrete, se for iPhone ou iPad e o app **não** estiver instalado (`navigator.standalone !== true` e sem `display-mode: standalone`), mostre:
  > Para receber o aviso de rega no iPhone: toque em **Compartilhar** → **Adicionar à Tela de Início** e abra o Smart Garden por lá.

## 8. Origem permitida

Hoje `isAllowedOrigin` aceita **qualquer** `*.lovable.app` e `*.lovableproject.com`, ou seja, apps de outras pessoas. Restrinja a:
- a prévia deste projeto;
- o endereço publicado deste projeto;
- o que estiver em `ALLOWED_ORIGIN_HOSTS`.

Escreva no código como adicionar um domínio próprio.

## 9. Publicar

Só depois dos itens acima:

**a) Publique** com o endereço `smart-garden-ia.lovable.app`. Se não estiver livre, escolha o mais próximo e me diga.

**b) Cron.** Hoje ele chama `https://project--ae9ae530-ced6-41c2-a9d9-8f939661629d.lovable.app/api/public/send-reminders`, e esse endereço sempre respondeu 404.
- Reagende o job `send-watering-reminders` com o endereço publicado.
- O segredo continua vindo de `app_config`, **sem** escrever o valor no comando.
- Confira que existe **exatamente 1** job.

**c) Confira o cron.** 10 minutos depois:
```sql
SELECT status_code, count(*) FROM net._http_response
WHERE created > now() - interval '15 minutes' GROUP BY 1;
```
Precisa aparecer **200**.

**d) Notificações.** Confira que existem os secrets `VAPID_PUBLIC_KEY` e `VAPID_PRIVATE_KEY`. `/api/public/vapid-key` precisa responder 200. Se faltarem, gere o par e peça pelo formulário de secret.

**e)** Me mande o link publicado.
