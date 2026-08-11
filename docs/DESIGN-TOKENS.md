# Tokens de design

Linguagem visual do Smart Garden IA, validada no Lovable e portada para o Emergent.
Mantida aqui para que as duas implementações partam da mesma fonte.

## Tokens

```css
:root{
  --ink-900:#0d1117; --ink-700:#57606a; --ink-500:#8c959f; --ink-200:#d0d7de; --ink-100:#eaeef2;
  --bg:#ffffff; --bg-2:#f6f8fa; --bg-3:#eef1f4;
  --green:#22c37a; --green-dark:#159958; --green-100:#e3f8ee;
  --radius-sm:10px; --radius-md:16px; --radius-lg:24px; --radius-full:999px;
  --shadow-sm:0 1px 2px rgba(13,17,23,.06); --shadow-md:0 10px 30px rgba(13,17,23,.12);
}

@media (prefers-color-scheme: dark){
  :root{
    --ink-900:#f0f3f6; --ink-700:#b6bec6; --bg:#0d1117; --bg-2:#161b22; --bg-3:#1c2128;
    --ink-100:#1c2128; --ink-200:#2a3138;
  }
}
```

O modo escuro é automático via `prefers-color-scheme`, sem toggle manual. Os tokens de
tinta invertem de papel no escuro (`--ink-900` passa a ser quase branco), então componentes
escritos em cima dos tokens acompanham a troca sem precisar de regra própria.

## Aplicação

- **Tipografia:** Inter em tudo.
- **Botão primário:** gradiente `--green` → `--green-dark`, cantos `--radius-md`, elevação
  leve no hover, `scale(.96)` no clique.
- **Cards:** fundo `--bg-3`, cantos `--radius-md`, `--shadow-sm` só no hover.
- **Bolha de chat do usuário:** gradiente verde, cantos arredondados exceto o inferior
  direito — a "ponta" que aponta para quem enviou.
- **Loading:** três pontinhos verdes com bounce, no lugar de spinner.

## Cuidado ao aplicar

Estes tokens são **pele**: cores, cantos, sombras e tipografia. Aplicá-los não deve mudar
a estrutura nem a lógica de nenhuma tela. Se aplicar um token exigir mexer em layout ou
comportamento, o problema está no componente, não no token.
