# Smart Garden IA

Aplicativo de identificação de plantas por foto, com IA. O usuário fotografa uma planta e
recebe o nome (popular e científico), a rotina de rega, onde regar, os nutrientes, o solo
ideal, o passo a passo de plantio e os problemas comuns — tudo em português.

Este repositório é o **hub de coordenação** do projeto. O código-fonte vive hoje em duas
plataformas separadas (Lovable e Emergent), cada uma com o seu próprio sandbox e o seu
próprio git. Este repo mantém o que essas plataformas não guardam: a documentação da
arquitetura, o registro de auditoria, os tokens de design validados e os assets próprios.

## Onde está cada coisa

| Plataforma | Papel | Stack | Estado |
|---|---|---|---|
| **Lovable** — `bloom-brighten-build` | Implementação principal, mais atual | TanStack Start + TypeScript, Supabase, shadcn/ui | Ativa, build passando |
| **Emergent** — `smart-plant-doc` | Implementação paralela, com contas Google e painel admin | FastAPI + MongoDB + React | **Pausada — créditos esgotados** |
| **GitHub** — este repo | Documentação, auditoria, assets | — | Ativo |
| **Higgsfield** | Geração dos assets visuais próprios | — | Free plan (4K exige plano pago) |

Links do projeto Lovable:

- Editor: <https://lovable.dev/projects/ae9ae530-ced6-41c2-a9d9-8f939661629d>
- Preview: <https://id-preview--ae9ae530-ced6-41c2-a9d9-8f939661629d.lovable.app>

## Funcionalidades

- **Identificação por foto** — envia a imagem para o gateway de IA (`google/gemini-2.5-flash`)
  e devolve a ficha completa da planta. Abaixo de 50% de confiança devolve `plant: null`
  em vez de inventar uma resposta.
- **Catálogo offline de 8 plantas** — samambaia, costela-de-adão, orquídea, cacto, girassol,
  rosa, palmeira e lavanda, com ficha completa escrita à mão (`src/components/smart-garden/plants.ts`).
- **Chat por planta, com memória** — cada planta tem a sua conversa, persistida no Supabase
  e restrita a assuntos de jardinagem.
- **Lembretes de rega** — frequência, horário e quantidade por planta.

## Documentação

- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — como o app está montado: rotas, API,
  banco de dados e as defesas já existentes nos endpoints.
- [`docs/AUDIT.md`](docs/AUDIT.md) — auditoria de código de 11/08/2026, com os pontos
  abertos em ordem de prioridade.
- [`docs/PATCHES.md`](docs/PATCHES.md) — o código pronto das duas correções mais urgentes.
- [`docs/DESIGN-TOKENS.md`](docs/DESIGN-TOKENS.md) — a linguagem visual validada, com os
  tokens prontos para colar.

## Assets

Gerados no Higgsfield, próprios do projeto (sem dependência de banco de imagens de terceiros):

- `assets/og-smart-garden.png` — imagem de preview social (Open Graph). Monstera, orquídea
  e samambaia em luz natural, com espaço negativo à direita reservado para texto.
- `assets/plant-samambaia.png` — foto de catálogo da samambaia, para substituir o hotlink
  do Unsplash na galeria. Serve também como amostra do padrão visual das outras quatro que
  faltam (ver AUDIT #4).

## Estado atual

**As duas plataformas de build estão sem créditos**, então as correções do `PATCHES.md`
foram escritas mas não aplicadas:

- **Lovable** — workspace sem créditos. As correções estão prontas em `docs/PATCHES.md`,
  é colar ou pedir ao agente que aplique.
- **Emergent** — job pausado por créditos esgotados, com mudanças da última iteração
  **ainda não verificadas** (o testing agent foi interrompido antes de rodar).

### Ordem sugerida quando os créditos voltarem

1. **Emergent:** rodar o testing agent até o fim, antes de qualquer coisa nova — hoje há
   código não validado em produção (AUDIT #6).
2. **Lovable:** aplicar os dois patches (AUDIT #1 e #2).
3. **Lovable:** persistir a foto do usuário no Supabase Storage (AUDIT #3).
4. **Higgsfield:** gerar as quatro fotos restantes da galeria — costela-de-adão, cacto,
   girassol e rosa (AUDIT #4). São 2 créditos por imagem no plano free; 4K exige plano pago.
