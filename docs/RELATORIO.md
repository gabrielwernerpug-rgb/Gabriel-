# Relatório — Smart Garden IA

**Atualizado em 16/10/2026** · Projeto Lovable `ae9ae530-…` · Último commit `12ea626`

---

## Em uma frase

A parte de **segurança e custo foi corrigida no código** (Fase 1), mas o app está
**fora do ar**: o Lovable **pausou o banco de dados** e os **créditos do
workspace acabaram**. Os dois só você consegue resolver. Depois disso, faltam 4
prompts — já escritos — para o app ficar pronto para publicar.

---

## 1. O que está bloqueando agora

### 🔴 O banco de dados está pausado

- O endereço do banco (`smlbsomrtotqqidflayd.supabase.co`) **não existe mais no
  DNS**. Minhas consultas e as do agente do Lovable dão erro.
- Sem banco, **nada funciona**: login, catálogo, identificação, chat, lembretes.
- Segundo a [documentação do Lovable](https://docs.lovable.dev/features/advanced-settings),
  o Lovable pausa o banco depois de um tempo sem uso, ou quando o workspace fica
  **sem crédito**. **Os dados ficam guardados**, e a pausa é reversível.

**Como religar:**
1. Abra o projeto **SMART GARDEN IA** no Lovable.
2. Toque em **Wake up** no aviso que aparece no chat do projeto. Ou vá em
   **More (…) → Cloud → Overview** e toque em **Wake up** no cartão do projeto
   pausado.
3. Se o cartão disser que **acabaram os créditos**, primeiro é preciso ter
   crédito (abaixo) e **depois** tocar em Wake up. Colocar crédito não religa
   sozinho.

### 🔴 Os créditos do Lovable acabaram

- A Fase 1 custou **5 créditos**. Quando tentei mandar a Fase 2, o Lovable
  respondeu: *"Your workspace is out of credits"*.
- O workspace está no plano **grátis**. Os créditos grátis renovam com o tempo
  (confira em **Configurações → Plano e créditos**), ou dá para comprar em
  [lovable.dev/settings/billing](https://lovable.dev/settings/billing).
- Cada fase custa mais ou menos o mesmo que a Fase 1, uns **5 créditos**.

---

## 2. O que foi feito hoje (Fase 1 — segurança e custo)

Commit `12ea626`. **Revisei o código linha por linha** e está correto.

| # | Problema | O que mudou |
|---|---|---|
| 1 | Qualquer pessoa na internet conseguia **zerar a própria cota** | Migration escrita: `REVOKE ... FROM PUBLIC` e trava para funções futuras. ⏳ **Aplica quando o banco voltar.** |
| 2 | Conta anônima furava o login | ✅ O servidor recusa token anônimo (401). O código morto de "vincular conta anônima" foi removido. |
| 3 | Cada mensagem do chat **gastava uma identificação** | ✅ O chat tem cota própria (`chat`) e **confere o plano**: o grátis recebe "recurso do Pro". |
| 4 | Dava para **gravar planta inventada** no catálogo público | ✅ A escolha de candidata vem de uma sessão do servidor (`identifyId`), nunca do texto do cliente. O catálogo só grava espécie **confirmada pelo GBIF**. |
| 5 | Foto borrada saía de graça, e escolher a candidata cobrava de novo | ✅ **1 foto = 1 crédito.** Escolher a candidata e corrigir são grátis. A cota só volta em falha técnica. |
| 6 | Resposta torta da IA podia derrubar a tela | ✅ O plano de cuidado é validado (`zod`), com uma nova tentativa. Nada inválido é mostrado nem gravado. |
| 7 | Foto de 4–11 MB, com GPS, enviada sem compressão | ✅ O celular comprime para 1280 px em JPEG, **sem GPS**. O servidor recusa acima de 6 MB e formato falso, **antes** de cobrar. |
| 8 | Sem teto de gasto | ✅ Disjuntor: no máximo 300 chamadas de IA e 450 do Pl@ntNet por dia, mais um **botão de pânico** (`ai_enabled`). ⏳ Depende da migration. |
| 9 | Ninguém sabia quanto custa cada uso | ✅ Cada chamada de IA grava tokens e tempo em `ai_calls`. ⏳ Depende da migration. |
| 10 | Código morto | ✅ Removido. |

**Importante:** enquanto a migration da Fase 1 não for aplicada, o disjuntor não
acha a configuração e trata a IA como desligada (falha fechada, de propósito).
**Não publique antes da Fase 1b.**

---

## 3. O que falta, em ordem

Os prompts estão prontos em [`docs/prompts/`](prompts/). Cole **um por vez** no
chat do projeto no Lovable e espere terminar antes do próximo.

| Ordem | Prompt | O que resolve | Custo aprox. |
|---|---|---|---|
| **1b** | [`fase-1b-aplicar-migration.md`](prompts/fase-1b-aplicar-migration.md) | Aplica o banco da Fase 1 e testa. ⚠️ O Lovable vai pedir para você **aprovar** a migration: toque em aprovar. | pouco |
| **2** | [`fase-2-conta-e-plano.md`](prompts/fase-2-conta-e-plano.md) | Botão **Entrar/Sair**, página **Minha conta**, **teste grátis de 14 dias**, excluir conta, tela que não finge que salvou, resultado sem cartões vazios, nome e ícone do app. | ~5 |
| **3** | [`fase-3-identificacao-e-publicar.md`](prompts/fase-3-identificacao-e-publicar.md) | Fotos de exemplo nas candidatas, crédito do Pl@ntNet, catálogo clicável, privacidade e termos (LGPD), aviso de toxicidade, app instalável no iPhone, **publicação** e conserto do cron. | ~5 |
| **4** | [`fase-4-lembretes-e-ajustes.md`](prompts/fase-4-lembretes-e-ajustes.md) | Lembrete da planta identificada, foto guardada de verdade, histórico do chat certo, e o **teste final de ponta a ponta**. | ~5 |
| 5–7 | [`fases-5-a-7-funcionalidades.md`](prompts/fases-5-a-7-funcionalidades.md) | Minhas plantas, **diagnóstico de planta doente**, **diário com foto**, assinatura (Stripe) e chat que consulta fontes. | ~5 cada |

**Depois da Fase 4, o app está pronto para mostrar ao seu tio.** As Fases 5–7 são
as funcionalidades novas que você pediu.

---

## 4. Coisas que só você pode fazer

- [ ] **Ter crédito** no Lovable (esperar renovar ou comprar)
- [ ] **Wake up** no banco (seção 1)
- [ ] **Aprovar a migration** quando o Lovable pedir, na Fase 1b
- [ ] **Desligar o login anônimo:** no projeto, procure em **Cloud → Users**, nas configurações de autenticação (*Auth settings* ou *Providers*), e desligue **Anonymous**. Não conferi o nome exato do menu. Se não achar, peça ao agente na Fase 1b o caminho exato
- [ ] **Pl@ntNet:** ficar com **uma conta só** (os [termos](https://my.plantnet.org/terms_of_use) proíbem mais de uma conta grátis por pessoa). Se a chave que está no Secret é a mesma que foi colada no chat em setembro (`2b10hq…`), **gere outra** e troque
- [ ] **E-mail de contato**: o Lovable vai pedir pelo formulário de secret `CONTACT_EMAIL` na Fase 3. Ele aparece na página de privacidade
- [ ] **Entrar com o Google** no app depois da Fase 2. Sua conta nasce com 14 dias de Pro

---

## 5. Estado do banco na última leitura (27/09)

Não deu para ler de novo hoje, porque o banco está pausado.

| | |
|---|---|
| Usuários | 19, **todos anônimos** (nenhum Google) |
| Identificações registradas | 0 |
| Catálogo | 8 plantas (as iniciais) |
| Lembretes / notificações | 0 / 0 |
| Cron dos lembretes | 72 chamadas/dia, **todas 404** (o app nunca foi publicado). A Fase 3 conserta |

---

## Documentos

- [`ANALISE-COMPLETA.md`](ANALISE-COMPLETA.md) — a análise de 27/09, com o problema, a prova e a correção de cada item
- [`prompts/`](prompts/) — os prompts prontos para colar
- [`ARQUITETURA.md`](ARQUITETURA.md) — como o app é montado
