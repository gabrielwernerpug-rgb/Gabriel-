Um problema só: **faltam os textos legais e os avisos de segurança.** O app faz login com Google e recebe fotos, então cai na LGPD.

Faça:

1. **Página `/privacidade`**, em português simples. Deve dizer:
   - quais dados guardamos: e-mail, nome e foto do Google, conversas, lembretes e uso;
   - que **as fotos das plantas vão para o Google (Gemini) e para o Pl@ntNet, na França**, para identificação. O Pl@ntNet diz que não guarda a foto, só o histórico da consulta;
   - que a foto sai do celular comprimida e **sem localização GPS**;
   - como apagar tudo: o botão em `/conta`;
   - o contato: peça ao dono pelo formulário de secret `CONTACT_EMAIL`, sem pedir no chat, e mostre esse valor.
2. **Página `/termos`.** O app é informativo, a IA pode errar, e não substitui agrônomo ou viveirista.
3. **Rodapé** em todas as páginas com:
   - "Identificação de espécies com a tecnologia [Pl@ntNet](https://my.plantnet.org/)" (os termos do Pl@ntNet pedem esse crédito);
   - links para Privacidade e Termos.
   Ponha os mesmos links também na tela de login.
4. **Toxicidade:**
   - Campo **opcional** no schema do plano de cuidado: `toxicidade: { pets: "sim"|"não"|"incerto", criancas: "sim"|"não"|"incerto", nota: string }`. Opcional para não invalidar o catálogo antigo.
   - Peça esse campo no prompt.
   - Mostre em destaque quando for "sim".
   - Preencha à mão nas 8 plantas de `plants.ts`: a costela-de-adão é tóxica para cães e gatos.
5. **`plants.ts`:**
   - Na palmeira, troque "Remova e QUEIME as folhas afetadas" por "Remova as folhas afetadas e descarte em saco fechado, separado do lixo comum e da compostagem".
   - Onde citar fungicida ou inseticida **sistêmico**, acrescente "(consulte um agrônomo; pode exigir receituário)".

No fim: build limpo e o que mudou.
