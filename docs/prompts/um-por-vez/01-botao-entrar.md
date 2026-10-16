Um problema só: **o app exige login, mas não tem botão de Entrar em lugar nenhum.**

`loadAccount()` e `signOut()` existem em `src/lib/garden-store.ts`, mas nenhuma tela usa. Quem toca na câmera sem estar logado recebe um texto vermelho e não tem para onde ir.

Faça só isto, **sem mudar banco**:

1. **Cabeçalho** no topo da home (`SmartGarden.tsx`), discreto e no estilo do app:
   - deslogado: botão **Entrar**, que leva a `/auth`;
   - logado: a foto do Google (ou a inicial do nome) + o selo do plano (**Grátis** ou **Pro**) + um menu com **Sair**.
   - O **Sair** chama `signOut()` e recarrega a home.
2. **Login antes da câmera.** Tocou em "Abrir câmera ou galeria" ou na área da foto **sem estar logado**? Não abre a câmera. Abre um aviso: "Entre com o Google para identificar sua planta", com **Entrar com o Google** (→ `/auth`) e **Agora não**.
3. **Toda resposta 401** da identificação mostra esse mesmo aviso, nunca só o texto vermelho.
4. **Voltar para onde estava.** Antes de ir para `/auth`, guarde a rota atual em `sessionStorage`. Em `auth.tsx`, depois de entrar, volte para ela (ou para `/`).
5. Atualize o cabeçalho com `supabase.auth.onAuthStateChange`, sem precisar recarregar.

No fim: build limpo e o que mudou em cada arquivo.
