# Smart Garden IA 🌱

Aplicativo de identificação de plantas por foto, com IA. O usuário tira uma foto,
a IA identifica a espécie e devolve o plano de cuidado completo: rega (frequência,
quantidade e **onde** regar), nutrientes, solo ideal, passo a passo de plantio e
diagnóstico de problemas comuns. Depois, o usuário pode conversar com a IA sobre
aquela planta específica (com memória) e criar lembretes de rega.

Este repositório é o **hub central** do projeto: documentação de arquitetura,
assets visuais e roadmap. O código-fonte vive nas plataformas de build
(veja [Onde está o código](#onde-está-o-código)).

---

## Estado atual

O projeto existe hoje em **duas implementações paralelas**, cada uma com pontos
fortes diferentes:

| | **Lovable — "Bloom Booster"** | **Emergent — "smart-plant-doc"** |
|---|---|---|
| Stack | TanStack Start + TypeScript + Tailwind | FastAPI + MongoDB + React |
| Auth | Supabase (login anônimo) | Google OAuth (sessão por cookie) |
| Identificação por foto | ✅ Gemini 2.5 Flash via AI Gateway | ✅ LLM via Emergent key |
| Chat com memória | ✅ Persistido em Postgres | ✅ Persistido em Mongo |
| Lembretes de rega | ✅ | ✅ (com "due" e "upcoming") |
| Diário da planta | ❌ | ✅ |
| Link de compartilhar | ❌ | ✅ (token `secrets.token_urlsafe`) |
| Painel admin | ❌ | ✅ (com checagem real no backend) |
| Rate limit | ✅ por IP, em memória (10/min) | ✅ por usuário, no Mongo (20/dia) |
| **Status** | 🟢 Ativo | 🔴 **Bloqueado — créditos esgotados** |

> **Atenção:** o build do Emergent está parado desde 09/08 por falta de créditos.
> O último pedido (rodar o testing agent até o fim) não chegou a executar.
> Detalhes em [`docs/ARQUITETURA.md`](docs/ARQUITETURA.md#emergent--bloqueado).

---

## Onde está o código

| Plataforma | Link |
|---|---|
| Lovable (editor) | https://lovable.dev/projects/ae9ae530-ced6-41c2-a9d9-8f939661629d |
| Lovable (preview) | https://id-preview--ae9ae530-ced6-41c2-a9d9-8f939661629d.lovable.app |
| Emergent (preview) | https://smart-plant-doc.preview.emergentagent.com |

---

## O que tem neste repositório

```
assets/plants/      Fotos das plantas geradas por IA, prontas para produção
  MANIFEST.md       Modelo, prompt e proveniência de cada imagem
docs/
  ARQUITETURA.md    As duas implementações, modelo de dados e contrato de API
  ROADMAP.md        Melhorias priorizadas, com esforço e impacto
```

### Assets de planta

As fotos em `assets/plants/` substituem *hotlinks* diretos ao Unsplash que ainda
existiam no catálogo. Hotlink é frágil: a URL pode sumir, não dá para otimizar e
adiciona uma dependência externa no carregamento. As imagens aqui são geradas,
otimizadas (~100–170 KB cada, contra ~4 MB do original) e versionadas junto do
projeto.

| Planta | Arquivo | Status |
|---|---|---|
| Costela-de-Adão (*Monstera deliciosa*) | `plant-monstera.jpg` | ✅ Gerada |
| Girassol (*Helianthus annuus*) | `plant-sunflower.jpg` | ✅ Gerada |
| Rosa (*Rosa spp.*) | `plant-rose.jpg` | ✅ Gerada |
| Samambaia (*Nephrolepis exaltata*) | — | ⏳ Pendente |
| Cacto (*Cactaceae spp.*) | — | ⏳ Pendente |

Orquídea, palmeira e lavanda já usam assets locais no projeto Lovable e não
precisavam de substituição.

---

## Ferramentas usadas

- **Lovable** — build e iteração do front-end
- **Emergent** — build do back-end completo (FastAPI + Mongo)
- **Higgsfield** — geração das fotos de planta (modelo `z_image`)
- **GitHub** — este repositório: documentação, assets e histórico
