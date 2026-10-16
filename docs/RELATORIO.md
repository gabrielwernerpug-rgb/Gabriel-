# Relatório — Smart Garden IA

**Atualizado em 16/10/2026, 14h30 (UTC)** · Projeto Lovable `ae9ae530-…` · Último commit `12ea626`

---

## Em uma frase

**Tudo que era de banco está corrigido e testado**: segurança, custo, teste
grátis de 14 dias, excluir conta e lembretes. O banco voltou a funcionar. Falta
a parte de **tela**, que só o agente do Lovable consegue mexer, e **os créditos
do Lovable estão zerados**. São 16 mensagens pequenas, já escritas, para o app
ficar pronto para publicar.

---

## ✅ Atualização da tarde (16/10): banco corrigido, um problema por vez

Você religou o banco (**Wake up**). Corrigi tudo que era de banco **direto
nele**, sem gastar crédito do Lovable. Cada correção foi testada antes de passar
para a próxima. Os testes que mexem em dados foram feitos dentro de uma
transação desfeita no fim, então nenhum dado real mudou.

| # | Problema | Teste | Resultado |
|---|---|---|---|
| 1 | Qualquer pessoa na internet conseguia **zerar a própria cota** | Chamei a função pela internet, como um atacante | ✅ "permission denied" |
| 2 | Faltavam as tabelas da Fase 1, e a identificação respondia "manutenção" | Disjuntor com teto 1: a 1ª passa, a 2ª é barrada | ✅ |
| 3 | Funções antigas que faziam o chat gastar identificação | Contagem depois de apagar | ✅ 0 restantes |
| 4 | **Teste grátis de 14 dias** não existia | Conta Google nova → Pro por 14 dias; vencido → grátis; mesmo e-mail de novo → sem 2º teste | ✅ |
| 5 | **Excluir a conta deixava dados para trás** (LGPD) | Apaguei um usuário com 1 conversa e 5 mensagens | ✅ tudo apagado |
| 6 | Lembrete disparava na hora errada; quem saiu do Pro continuava recebendo | Criado depois do horário: não dispara; grátis: 0 enviados; Pro: 2; teto: barrou no 51º | ✅ |
| 7 | Dava para encher o banco com texto gigante ou correções sem fim | Mensagem de 5.000 letras barrada; 31ª correção do dia barrada | ✅ |
| — | Conferência geral de segurança | Tabela sem proteção, função aberta, tabela legível por visitante | ✅ nenhuma |

O SQL de tudo, com o teste de cada um, está em
[`sql/2026-10-16-correcoes.sql`](sql/2026-10-16-correcoes.sql). É idempotente:
quando houver crédito, a mensagem [`17-registrar-sql.md`](prompts/um-por-vez/17-registrar-sql.md)
transforma isso em migration do projeto.

**O que ainda depende de crédito:** os problemas de **tela**. Eles estão em
[`prompts/um-por-vez/`](prompts/um-por-vez/), **um problema por mensagem**,
na ordem. O primeiro é o botão de Entrar. Tentei mandar às 14h30 e o Lovable
recusou por falta de crédito.

**A seção 1 abaixo é da manhã.** O banco já foi religado. Os créditos continuam
zerados.

---

## 1. O que estava bloqueando de manhã

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

**Use os prompts de um problema por vez:** [`prompts/um-por-vez/`](prompts/um-por-vez/).
Cole um por vez no chat do projeto no Lovable e espere terminar antes do próximo.
A ordem e as dependências estão no [`LEIA-ME`](prompts/um-por-vez/LEIA-ME.md).

- **01 a 05:** entrar e sair, Minha conta, tela honesta, resultado sem cartões vazios, nome e ícone do app.
- **06 a 11:** fotos de exemplo nas candidatas, catálogo clicável, tempo limite, privacidade e termos, app instalável no iPhone, origem permitida.
- **12 a 15:** lembrete da planta identificada, histórico do chat, foto guardada de verdade, fotos do catálogo.
- **16:** publicar e consertar o cron. **Depois dele, o app está pronto para mostrar ao seu tio.**
- **17:** registrar o SQL de hoje como migration do projeto.

Os prompts por fase em [`prompts/`](prompts/) continuam como referência. **A
parte de banco deles (1b e o teste grátis da Fase 2) já foi feita.**

Depois: [`fases-5-a-7-funcionalidades.md`](prompts/fases-5-a-7-funcionalidades.md)
— Minhas plantas, **diagnóstico de planta doente**, **diário com foto**,
assinatura e chat que consulta fontes.

---

## 4. Coisas que só você pode fazer

- [ ] **Ter crédito** no Lovable (esperar renovar ou comprar). **É o único bloqueio que sobrou.**
- [x] ~~Wake up no banco~~ (feito)
- [x] ~~Aprovar a migration~~ (não precisa mais: apliquei direto no banco)
- [ ] **Desligar o login anônimo:** no projeto, procure em **Cloud → Users**, nas configurações de autenticação (*Auth settings* ou *Providers*), e desligue **Anonymous**. Não conferi o nome exato do menu. O servidor já recusa conta anônima, então isto é uma segunda trava
- [ ] **Pl@ntNet:** ficar com **uma conta só** (os [termos](https://my.plantnet.org/terms_of_use) proíbem mais de uma conta grátis por pessoa). Se a chave que está no Secret é a mesma que foi colada no chat em setembro (`2b10hq…`), **gere outra** e troque
- [ ] **E-mail de contato:** o Lovable vai pedir pelo formulário de secret `CONTACT_EMAIL` na mensagem 09. Ele aparece na página de privacidade
- [ ] **Entrar com o Google** no app depois da mensagem 01. Sua conta nasce com 14 dias de Pro

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
