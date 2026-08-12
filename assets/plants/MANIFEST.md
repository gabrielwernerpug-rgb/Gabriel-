# Manifest dos assets de planta

Fotos geradas por IA para substituir hotlinks diretos ao Unsplash no catálogo
(`src/components/smart-garden/plants.ts` do projeto Lovable).

**Por que substituir:** hotlink para o Unsplash significa uma URL que pode mudar
ou sair do ar, sem controle de otimização e com uma requisição a um domínio
externo no caminho crítico de carregamento. Asset versionado no projeto resolve
os três.

## Parâmetros de geração

| | |
|---|---|
| Plataforma | Higgsfield |
| Modelo | `z_image` (Tongyi-MAI) |
| Aspect ratio | `4:3` |
| Resolução gerada | 2048 × 1536 PNG |
| Custo | 0,15 crédito por imagem |

## Pós-processamento

PNG de ~4 MB → JPEG de ~100–170 KB (**redução de ~96%**), sem perda visível nos
tamanhos em que o app renderiza (900 px no detalhe, 200 px no thumb):

```python
from PIL import Image
im = Image.open(src).convert('RGB')
im.thumbnail((1400, 1400), Image.LANCZOS)
im.save(out, 'JPEG', quality=86, optimize=True, progressive=True)
```

1400 px de largura cobre o uso em 900 px com folga para telas retina.

---

## Imagens

### ✅ `plant-monstera.jpg` — Costela-de-Adão (*Monstera deliciosa*)
Chave no catálogo: `monstera` · 1400 × 1050 · 174 KB

> Professional botanical photograph of a healthy Monstera deliciosa in a neutral
> ceramic pot, large glossy dark green leaves with characteristic natural splits
> and holes, soft diffused daylight, clean minimal white background, shallow depth
> of field, crisp detail on leaf veins, high resolution editorial plant
> photography, photorealistic, no text, no watermark

### ✅ `plant-sunflower.jpg` — Girassol (*Helianthus annuus*)
Chave no catálogo: `girassol` · 1400 × 1050 · 150 KB

> Professional botanical photograph of a single vibrant sunflower (Helianthus
> annuus) in full bloom, bright golden yellow petals and detailed dark seed head,
> fresh green leaves and stem, soft natural daylight, clean minimal light
> background with gentle blur, shallow depth of field, high resolution editorial
> plant photography, photorealistic, no text, no watermark

### ✅ `plant-rose.jpg` — Rosa (*Rosa spp.*)
Chave no catálogo: `rosa` · 1400 × 1050 · 98 KB

> Professional botanical photograph of a single fresh red garden rose in full
> bloom, velvety layered petals with morning dew, deep green foliage, soft natural
> daylight, clean minimal neutral background, shallow depth of field, crisp petal
> detail, high resolution editorial plant photography, photorealistic, no text,
> no watermark

### ✅ `plant-cactus.jpg` — Cacto (*Cactaceae spp.*)
Chave no catálogo: `cacto` · 1400 × 1050 · 142 KB

> Professional botanical photograph of a healthy columnar cactus in a matte
> terracotta pot, sharply defined ribs and fine spines, warm natural sunlight,
> clean minimal sand-beige background, shallow depth of field, crisp macro detail
> on the spines, high resolution editorial plant photography, photorealistic, no
> text, no watermark

---

## ⏳ Pendente

Prompt pronto — basta rodar no `z_image` com `aspect_ratio: "4:3"` e aplicar o
pós-processamento acima. As duas tentativas de gerar esta imagem bateram em
`429 rate_limit_reached` no backend do modelo; é só tentar de novo mais tarde.

### `plant-fern.jpg` — Samambaia (*Nephrolepis exaltata*)
Chave no catálogo: `samambaia`

> Professional botanical photograph of a lush healthy Boston fern (Nephrolepis
> exaltata) in a simple terracotta pot, vibrant green arching fronds with finely
> detailed leaflets, soft natural window daylight from the left, clean minimal
> off-white background, shallow depth of field, sharp focus on foliage, high
> resolution editorial plant photography, photorealistic, no text, no watermark

---

## Já resolvidas

Orquídea, palmeira e lavanda já usam assets locais no projeto Lovable
(`src/assets/plant-orchid.jpg`, `plant-palm.jpg`, `plant-lavender.jpg`) e não
precisavam de substituição.

## Diretriz para novas imagens

Manter a mesma linguagem visual: **fundo claro e limpo**, luz natural difusa,
profundidade de campo rasa, planta saudável e centralizada, sem texto nem
marca d'água. O catálogo é renderizado em grade — fundos díspares (escuros,
cheios de cena) quebram a leitura da lista.
