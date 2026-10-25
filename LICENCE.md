# Licença — PokéPOS 1.2

**PokéPOS — Sistema privado de estoque, entregas e caixa da PokéBottons** © 2026 Ruan Oliveira Lima.

Este projeto está licenciado sob a <a href="https://creativecommons.org/licenses/by-sa/4.0/deed.pt-br" target="_blank" rel="license noopener noreferrer">Creative Commons Atribuição-CompartilhaIgual 4.0 Internacional (CC BY-SA 4.0)</a>.

---

## Você tem permissão para

- **Compartilhar** — copiar e redistribuir o material em qualquer suporte ou formato
- **Adaptar** — remixar, transformar e criar a partir do material para qualquer fim, inclusive comercial

Desde que respeite os termos desta licença.

---

## Sob as seguintes condições

**Atribuição** — Você deve dar o crédito apropriado ao autor original, incluir um link para a licença e indicar se foram feitas alterações. Você pode fazê-lo de qualquer forma razoável, mas não de forma que sugira que o licenciante endossa você ou seu uso.

**CompartilhaIgual** — Se você remixar, transformar ou criar a partir deste material, deverá distribuir suas contribuições sob a mesma licença CC BY-SA 4.0.

Atribuição sugerida:

> Derivado do projeto PokéPOS por [Ruan Oliveira Lima](https://www.instagram.com/ruanoliveiralima_/) © 2026 — <a href="https://github.com/limaoruan/pokepos" target="_blank" rel="noopener noreferrer">https://github.com/limaoruan/pokepos</a> — <a href="https://creativecommons.org/licenses/by-sa/4.0/deed.pt-br" target="_blank" rel="license noopener noreferrer">CC-BY-SA 4.0</a>

---

## O que está coberto por esta licença

- Código-fonte: `index.html`, `config.js`, `service-worker.js`
- Script SQL: `setup_supabase.sql`
- Ativos visuais originais: `logo.png`, `og-image.jpg`, `favicon.ico`, `favicon-16.png`, `favicon-32.png`, `favicon-48.png`, `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`
- Configuração e publicação: `manifest.webmanifest`, `robots.txt`, `.nojekyll`, `.github/workflows/manter-supabase-ativo.yml`
- Documentação: `README.md`, `LICENCE.md`

---

## Dependências de terceiros

Este projeto utiliza serviços e bibliotecas de terceiros com suas próprias licenças e termos de uso:

| Serviço / Biblioteca | Uso | Licença / Termos |
|---|---|---|
| [Supabase](https://supabase.com) | Banco de dados e autenticação (login), acessados direto pela API REST e de autenticação | [Apache 2.0](https://github.com/supabase/supabase/blob/master/LICENSE) |
| [GitHub Pages e GitHub Actions](https://github.com) | Hospedagem do site (Pages) e consulta agendada que mantém o Supabase ativo (Actions) | [Termos de serviço do GitHub](https://docs.github.com/pt/site-policy/github-terms/github-terms-of-service) |
| [Claude (Anthropic)](https://www.anthropic.com) | Assistência com IA no desenvolvimento | [Política de Uso Anthropic](https://www.anthropic.com/legal/aup) |
