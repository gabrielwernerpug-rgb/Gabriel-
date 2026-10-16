Um problema só: **o app ainda tem cara de projeto genérico e mostra confiança inventada.**

Faça:

1. **`__root.tsx`:**
   - Hoje: `title "Lovable App"`, `description "Lovable Generated Project"`, `author "Lovable"`, `twitter:site "@Lovable"` e `<html lang="en">`.
   - Troque por **Smart Garden IA**, descrição em português e `lang="pt-BR"`.
   - Páginas 404 e de erro em português.
2. **Favicon SVG** com o logo do app (o broto verde de `IconLogo`).
3. **Imagem de compartilhamento** 1200×630 para o `og:image`: fundo verde, logo e "Smart Garden IA — identifique sua planta pela foto".
4. As 8 plantas de `plants.ts` têm "97% de confiança" fixo. Abrindo pelo catálogo, mostre **"Do catálogo"**.
5. Tire o falso "Analisando sua planta… A IA está identificando" de 800 ms em `startAnalysis`. Planta do catálogo abre direto.

No fim: build limpo e o que mudou.
