# Auditoria — 11/08/2026

Revisão do código do projeto Lovable `bloom-brighten-build` no commit
`cc90bf3ab77527e4a6e24af0ccbae26b1e58d923`, mais o estado da implementação do Emergent.

**Resumo:** a base está mais sólida do que o normal para um app gerado por IA — o rate
limit é persistente no banco (não em memória), o RLS está completo nas três tabelas, as
entradas do chat são validadas e o corte de confiança da identificação é aplicado no
servidor. Os pontos abaixo são o que sobrou, em ordem de prioridade.

---

## 1. `identify-plant` aceita imagem de tamanho ilimitado — ALTA

`src/routes/api/identify-plant.ts`

O corpo da requisição é lido e o campo `image` é usado sem nenhum limite de tamanho:

```ts
const image = typeof body.image === "string" ? body.image.trim() : "";
if (!image) return json({ error: "Missing 'image'" }, 400);
// segue direto para o gateway de IA
```

Compare com `chat-plant.ts`, que limita mensagens a 2000 caracteres e o array a 20 itens.
A rota de identificação não tem o equivalente.

**Consequência:** um chamador pode enviar uma base64 de dezenas de megabytes. O payload é
mantido em memória e repassado ao gateway de IA, que cobra por token de imagem. O rate
limit de 10/min por IP limita a *quantidade* de chamadas, mas não o *tamanho* de cada uma —
10 requisições de 50 MB por minuto passam pelo limite atual sem serem barradas.

**Correção:** rejeitar com `413` acima de um teto (~8 MB de base64, que cobre com folga uma
foto de celular). Checar antes de qualquer chamada ao gateway.

---

## 2. Metadados ainda são o boilerplate do Lovable — MÉDIA

`src/routes/__root.tsx`

```ts
{ title: "Lovable App" },
{ name: "description", content: "Lovable Generated Project" },
{ name: "author", content: "Lovable" },
{ property: "og:title", content: "Lovable App" },
{ name: "twitter:site", content: "@Lovable" },
```

Três problemas de uma vez:

- O app se apresenta como "Lovable App" na aba do navegador e em qualquer compartilhamento.
- **Não existe `og:image`.** O `twitter:card` está como `summary_large_image`, que reserva
  espaço para uma imagem grande — sem `og:image`, o link compartilhado aparece com um
  retângulo vazio.
- O shell declara `<html lang="en">` enquanto todo o conteúdo do app é português. Leitores
  de tela usam esse atributo para escolher a pronúncia, então isso é um bug de
  acessibilidade real, além de afetar SEO.

**Correção:** metadados próprios em pt-BR, `lang="pt-BR"` no `<html>`, e apontar `og:image`
para `assets/og-smart-garden.png` deste repositório.

---

## 3. A foto do usuário é descartada ao recarregar — MÉDIA (UX)

`src/lib/garden-store.ts`

```ts
const stripDataUrl = (v: string | undefined) =>
  !v || v.startsWith("data:") ? FALLBACK_IMG : v;
```

A decisão de não gravar base64 no Postgres está certa — o banco não é lugar para
megabytes de imagem. Mas o efeito para o usuário é que a planta que ele fotografou
reaparece com uma foto genérica de banco de imagens, o que faz a identificação parecer
não ter sido salva.

**Correção:** subir a foto para o Supabase Storage num bucket privado, com política por
`user_id`, e gravar só a URL. Mantém o banco leve e preserva a foto.

---

## 4. Cinco das oito plantas dependem de hotlink do Unsplash — BAIXA

`src/components/smart-garden/plants.ts`

Orquídea, palmeira e lavanda usam assets locais (`src/assets/`). As outras cinco —
samambaia, costela-de-adão, cacto, girassol e rosa — apontam para URLs do
`images.unsplash.com`. O mesmo vale para o `FALLBACK_IMG` do `garden-store.ts`.

**Consequência:** o app depende de um terceiro para renderizar a maior parte da galeria.
Se as URLs mudarem ou o Unsplash bloquear hotlink, a galeria quebra — e o visual fica
inconsistente entre as plantas com asset próprio e as demais.

**Correção:** gerar as cinco imagens que faltam e servi-las localmente. O plano free do
Higgsfield custa 2 créditos por imagem e não libera 4K (exige plano pago), então isso são
10 créditos para fechar a galeria inteira com assets próprios.

---

## 5. O rate limit falha liberando o acesso — informativo

`src/lib/api-guard.ts`

```ts
} catch (err) {
  console.error("rate limit check failed", err);
  return { ok: true, retryAfter: 0 };
}
```

Está comentado no código como intencional ("falha no banco não deve derrubar a
requisição"), e para um app de jardinagem é uma troca defensável. Registrado aqui só para
que a escolha seja consciente: enquanto o Supabase estiver indisponível, os endpoints de
IA ficam sem limite algum. Se o custo de IA virar um problema, esse é o ponto a inverter.

---

## 6. As correções do Emergent nunca foram verificadas — ALTA (processo)

O job `smart-plant-doc` está **pausado por créditos esgotados**. A última iteração aplicou:

- correção da race condition no `AuthCallback` do login (troca de `navigate()` por
  `window.location.replace("/dashboard")`);
- cota de IA de 20/dia por usuário na collection `ai_usage`;
- troca do token de compartilhamento de `uuid.uuid4().hex[:16]` (64 bits) por
  `secrets.token_urlsafe(16)` (128 bits);
- aplicação dos tokens visuais.

O testing agent foi **interrompido antes de executar qualquer teste** — ele chegou a
revisar o `server.py` e confirmar que o código estava lá, mas não rodou nada. Ou seja:
essas mudanças estão no código e **não foram validadas**, e a regressão do que já existia
(identificação, chat com memória, diário, lembretes, compartilhamento, admin) também não
foi checada.

**Ação:** ao recarregar os créditos, a primeira coisa a fazer no Emergent é rodar o
testing agent até o fim — antes de qualquer funcionalidade nova.
