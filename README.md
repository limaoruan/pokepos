# PokéPOS 1.2

Site **privado** da PokéBottons para controle de estoque, entregas e caixa. Exige login (e-mail e senha). Site estático (PWA, mobile first) feito por Ruan Oliveira Lima, hospedado no **GitHub Pages**, com banco de dados e login no **Supabase**. Acompanha o tema claro ou escuro do aparelho.

Esta pasta é a **raiz de um repositório** no GitHub (`pokepos`).

---

## O que faz

Tem 3 abas:
- **Estoque**: folhas (lotes) e bottons. Cada folha tem até 100 bottons.
- **À Receber**: bottons entregues que ainda não foram pagos. A aba mostra um selo com a quantidade pendente.
- **Caixa**: Qtd. de Bottons, Custo e Lucro, mais o histórico de eventos.

## Regras
- **PID**: formato `PID-000-000-000/00`. Os 9 primeiros dígitos são a folha e os 2 últimos, o botton.
- **Folha**: número de 000-000-000 a 999-999-999 (Lote = número + 1). **Botton**: número de 00 a 99 (Item = número + 1). Só cadastra número ainda inexistente.
- **Arte**: campo obrigatório no cadastro do botton (até 100 caracteres).
- **Entrega**: pede o preço de venda e a opção "valor a receber". Botton entregue não pode mais ser excluído.
- **Excluir folha**: pede confirmação e só funciona se nenhum botton da folha foi entregue. Excluir uma folha apaga os bottons não entregues dela.
- **Caixa**: ao receber um valor, 53,50% vão para o Custo e o restante para o Lucro. Se o custo tiver 3 casas decimais ou mais, ele é sempre arredondado para cima (ex.: R$ 5,00 → custo 2,68 e lucro 2,32). A Qtd. de Bottons conta na entrega, mesmo a receber. O Custo começa em zero: o dinheiro entra pelo botão **Investir** e sai pelo **Custear** (que não deixa o Custo ficar negativo). As duas ações exigem descrição (até 200 caracteres).
- **Valores**: o preço e os valores do Caixa aceitam vírgula (ex.: 4,50), com máximo de R$ 99.999.999,99.
- Horários são guardados em UTC e exibidos em America/Sao_Paulo.

## Como usar
1. Entre com o e-mail e a senha criados no Supabase. A sessão fica guardada no aparelho e renova sozinha, e o e-mail é lembrado; use **Sair** para encerrar.
2. **Estoque**: cadastre a folha (número) e abra-a para cadastrar os bottons (0 a 99), informando a **arte**.
   - O card da folha mostra o código, o Lote e "N botton(s) · M entregue(s)": verde quando todos foram entregues e vermelho quando falta entregar algum.
   - O card do botton mostra o PID, o Item, a arte, "Feito em" e o status. Botton não entregue mostra "falta entregar!", com os botões **ENTREGAR** e **Excluir**.
3. **Entregar**: informe o preço de venda. Marque "Ainda vou receber o valor" se ainda não foi pago.
4. **À Receber**: toque em **Recebi!** quando o pagamento chegar.
5. **Caixa**: acompanhe Bottons, Custo e Lucro. Use **Investir** para colocar dinheiro no Custo e **Custear** para retirar.
   - O histórico mostra os últimos 100 eventos de cada tipo (até 400 no total): Entrega, Recebimento, Custeio e Investimento.
   - O Recebimento mostra quanto foi para o Custo e quanto foi para o Lucro. Custeio e Investimento mostram a descrição.

**Listas:** em todas as listas (folhas, bottons, À Receber e histórico) aparece um card por vez. Navegue com **Anterior** e **Próxima**, com o contador (ex.: 2 / 7).

**Sem internet:** o app abre, mas os dados exigem conexão ("Sem conexão. Tente novamente.").

## Instalação

### 1. Supabase (banco e login)
1. Crie um projeto em supabase.com.
2. Em **Authentication**, **Sign In / Providers**, desligue **Allow new users to sign up** (obrigatório: só você deve entrar).
3. Em **SQL Editor**, cole todo o `setup_supabase.sql` desta pasta e execute **uma única vez**.
4. Em **Authentication**, **Users**, **Add user**, crie o seu e-mail e senha (marque **Auto Confirm User**).
5. Em **Project Settings**, **API Keys**, copie a **Project URL** e a chave **publishable** (ou **anon**).

O PokéPOS e o PIDgey usam o **mesmo projeto do Supabase**. Rode o setup do PokéPOS **primeiro** (ele cria as tabelas, as operações e as permissões) e o do PIDgey depois.

### 2. Configurar o site
- Em `config.js`, troque `SUPABASE_URL` pela Project URL e `SUPABASE_CHAVE` pela chave publishable.
- Essa chave pode ficar no repositório público: quem protege os dados é o banco. **Nunca** use a chave `secret` ou `service_role`.
- Se for publicar em outra conta do GitHub, troque `limaoruan` pelo seu usuário em `index.html` e no `LICENCE.md`.

### 3. Publicar no GitHub Pages
1. Crie um repositório **público** chamado `pokepos`.
2. Envie todo o conteúdo desta pasta para a raiz do repositório, inclusive a pasta `.github`. O arquivo `.nojekyll` é opcional.
3. Em **Settings**, **Pages**, escolha **Deploy from a branch**, branch `main`, pasta `/ (root)`.
4. Aguarde alguns minutos. O endereço será https://limaoruan.github.io/pokepos/

Se o seu aparelho ocultar ou não enviar a pasta `.github`, crie o workflow direto no GitHub: **Add file**, **Create new file**, nome `.github/workflows/manter-supabase-ativo.yml`, e cole o conteúdo do arquivo desta pasta.

### 4. Testar
1. Abra o endereço e entre com o e-mail e a senha criados no Supabase.
2. Cadastre uma folha e um botton para ver se o banco responde.
3. Em **Actions**, escolha **Manter Supabase ativo** e use **Run workflow**. Ele usa a função `consultar_pid`, criada pelo setup do PIDgey; se você não vai usar o PIDgey, rode o setup dele mesmo assim ou apague este workflow.

### 5. Instalar como app (opcional)
Os sites são PWA. No celular, abra o endereço do site e use **Adicionar à tela inicial**:
- **Android:** menu do navegador, **Instalar app** ou **Adicionar à tela inicial**.
- **iPhone:** botão **Compartilhar**, **Adicionar à Tela de Início**.

## Manutenção
O plano gratuito do Supabase pausa o projeto após cerca de 7 dias sem uso. O arquivo `.github/workflows/manter-supabase-ativo.yml` faz uma consulta pública de teste (`consultar_pid`, sem dados) 2 vezes por semana, às segundas e quintas, 00:00 no horário de Brasília, usando a URL e a chave do `config.js`.
- Ela usa a função `consultar_pid`, criada pelo `setup_supabase.sql` do PIDgey. Se você não usa o PIDgey, rode o setup dele mesmo assim (é só uma função) ou apague este workflow.
- Para testar na hora, abra **Actions**, escolha **Manter Supabase ativo** e use **Run workflow**.
- Se o GitHub desativar o agendamento por falta de atividade no repositório, reative em **Actions**. Se o projeto pausar, use **Restore** no painel do Supabase.

## Arquivos
- `index.html`: o site inteiro (HTML, CSS e JavaScript)
- `config.js`: URL e chave publishable do Supabase
- `setup_supabase.sql`: cria o banco do PokéPOS (rode uma única vez)
- `.github/workflows/manter-supabase-ativo.yml`: consulta agendada para o Supabase não pausar
- `service-worker.js`, `manifest.webmanifest`: PWA
- `logo.png`, `icon-*.png`, `favicon*`, `apple-touch-icon.png`, `og-image.jpg`: imagens
- `LICENCE.md`: licença do projeto
- `robots.txt`, `.nojekyll`

## Segurança
- **Cadastro de novos usuários desligado:** no Supabase, em **Authentication**, **Sign In / Providers**, mantenha **Allow new users to sign up** desligado. Se ficar ligado, qualquer pessoa pode criar uma conta e entrar.
- **Chave do `config.js`:** a chave **publishable** (ou **anon**) pode ficar no repositório público, porque quem protege os dados é o banco. **Nunca** coloque a chave `secret` ou `service_role`.
- **Banco:** as tabelas têm RLS ligado e só o usuário logado lê e altera. O histórico do Caixa não pode ser editado nem apagado pelo site.

---

© 2026 Ruan Oliveira Lima · Instagram: https://www.instagram.com/ruanoliveiralima_/
Licença: CC BY-SA 4.0 (texto completo no `LICENCE.md`)
