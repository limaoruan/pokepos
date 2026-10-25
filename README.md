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
- **Caixa**: ao receber um valor, 53,50% vão para o Custo e 46,50% para o Lucro. A Qtd. de Bottons conta na entrega, mesmo a receber. O Custo começa em zero: o dinheiro entra pelo botão **Investir** e sai pelo **Custear** (que não deixa o Custo ficar negativo). As duas ações exigem descrição (até 200 caracteres).
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
   - O histórico mostra os últimos 100 eventos, de 4 tipos: Entrega, Recebimento, Custeio e Investimento.
   - O Recebimento mostra quanto foi para o Custo e quanto foi para o Lucro. Custeio e Investimento mostram a descrição.

**Listas:** em todas as listas (folhas, bottons, À Receber e histórico) aparece um card por vez. Navegue com **Anterior** e **Próxima**, com o contador (ex.: 2 / 7).

**Sem internet:** o app abre, mas os dados exigem conexão ("Sem conexão. Tente novamente.").

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
