# Correções prontas para aplicar

As duas correções abaixo resolvem os itens **1** e **2** do [`AUDIT.md`](AUDIT.md).

Elas **não puderam ser aplicadas automaticamente**: o workspace do Lovable está sem
créditos, e o job do Emergent também. O código está escrito e pronto — é só colar assim
que os créditos voltarem, ou pedir ao agente do Lovable que aplique.

Nenhuma das duas muda estrutura, layout ou lógica de tela.

---

## Patch 1 — teto de tamanho da imagem em `/api/identify-plant`

**Arquivo:** `src/routes/api/identify-plant.ts`
**Resolve:** [AUDIT #1](AUDIT.md#1-identify-plant-aceita-imagem-de-tamanho-ilimitado--alta)

### a) Declare o teto junto das outras constantes do topo

```ts
const RATE_LIMIT = 10;
const WINDOW_SECONDS = 60;
// Uma foto de celular cabe folgada em 8 MB de base64. O rate limit por IP
// limita quantas chamadas, não o tamanho de cada uma.
const MAX_IMAGE_CHARS = 8 * 1024 * 1024;
```

### b) Cheque o tamanho logo depois de ler `image`

Substitua:

```ts
const image = typeof body.image === "string" ? body.image.trim() : "";
if (!image) return json({ error: "Missing 'image'" }, 400);
```

por:

```ts
const image = typeof body.image === "string" ? body.image.trim() : "";
if (!image) return json({ error: "Missing 'image'" }, 400);

if (image.length > MAX_IMAGE_CHARS) {
  return json(
    {
      error: "image_too_large",
      message: "Imagem muito grande. Envie uma foto de até 8 MB.",
    },
    413,
  );
}
```

A checagem tem que ficar **antes** da montagem do `imageUrl` e de qualquer `fetch` para o
gateway — o objetivo é não gastar a chamada paga.

### c) No front, trate o 413

Onde o `SmartGarden.tsx` já trata o `429` do rate limit, trate o `413` do mesmo jeito,
exibindo o `message` que o servidor devolve. O formato do corpo é o mesmo dos outros erros
(`error` + `message`), então normalmente é só mais um caso no `switch`/`if` existente.

---

## Patch 2 — metadados próprios, `lang="pt-BR"` e `og:image`

**Arquivo:** `src/routes/__root.tsx`
**Resolve:** [AUDIT #2](AUDIT.md#2-metadados-ainda-são-o-boilerplate-do-lovable--média)

**Pré-requisito:** copiar `assets/og-smart-garden.png` deste repositório para
`src/assets/og-smart-garden.png` no projeto Lovable.

### a) Importe o asset junto dos outros imports

```ts
import appCss from "../styles.css?url";
import ogImage from "../assets/og-smart-garden.png";
```

Importar o asset (em vez de chumbar uma URL absoluta) faz o bundler versionar o arquivo,
como já acontece com as fotos das plantas em `plants.ts`.

### b) Substitua o bloco `meta` inteiro

```ts
meta: [
  { charSet: "utf-8" },
  { name: "viewport", content: "width=device-width, initial-scale=1" },
  { title: "Smart Garden IA — Identifique sua planta por foto" },
  {
    name: "description",
    content:
      "Fotografe qualquer planta e descubra o nome, a rotina de rega, os nutrientes, o solo ideal e o passo a passo de plantio. Em português, com IA.",
  },
  { name: "author", content: "Smart Garden IA" },
  { property: "og:title", content: "Smart Garden IA — Identifique sua planta por foto" },
  {
    property: "og:description",
    content:
      "Fotografe qualquer planta e descubra o nome, a rotina de rega, os nutrientes, o solo ideal e o passo a passo de plantio. Em português, com IA.",
  },
  { property: "og:type", content: "website" },
  { property: "og:locale", content: "pt_BR" },
  { property: "og:image", content: ogImage },
  { property: "og:image:width", content: "1376" },
  { property: "og:image:height", content: "768" },
  {
    property: "og:image:alt",
    content:
      "Costela-de-adão, orquídea e samambaia sobre uma mesa de madeira clara, em luz natural",
  },
  { name: "twitter:card", content: "summary_large_image" },
  { name: "twitter:image", content: ogImage },
],
```

O `twitter:site` com `@Lovable` sai — só faz sentido se existir uma conta do projeto para
apontar.

### c) Corrija o idioma do shell

Em `RootShell`, troque:

```tsx
<html lang="en">
```

por:

```tsx
<html lang="pt-BR">
```

Todo o conteúdo do app é português. Leitores de tela usam esse atributo para escolher a
pronúncia, então o valor errado é um bug de acessibilidade, não só de SEO.
