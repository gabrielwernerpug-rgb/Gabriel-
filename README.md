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
- [`docs/DESIGN-TOKENS.md`](docs/DESIGN-TOKENS.md) — a linguagem visual validada, com os
  tokens prontos para colar.

## Assets

`assets/og-smart-garden.png` — imagem de preview social (Open Graph), gerada no Higgsfield.
Composição com monstera, orquídea e samambaia em luz natural, com espaço negativo à direita
reservado para sobreposição de texto.
