# [Onda 1] Árvore de rotas /b + layout + stubs de idiomas para todos os locales do host

## Manual citation

Não há citação direta da Resolução aqui — é trabalho estrutural que habilita as funções de negócio subsequentes. Porém:
- A exigência de **suporte multilíngue** vem da diretriz de zero-conflito com o Sure host: o Sure ship ~110 locales (`config/locales/defaults/`), e esta engine precisa acompanhá-los.

## Problem

O módulo hoje tem apenas `/b` (home estática). As próximas ondas vão adicionar recursos em `/b/parties`, `/b/organs`, `/b/organs/:id/bank_accounts`, etc. Antes de começar a codar isso, é melhor:
1. Estabelecer a árvore de rotas aninhada de maneira que funcione com a hierarquia de órgãos;
2. Garantir o layout do host (sidebar com item "Partidos" em cada idioma);
3. Gerar **stubs de locale** para todos os idiomas que o Sure suporta, para que nenhuma página do módulo disparar `translation missing` em usuário de outro idioma.

## Acceptance criteria

- [ ] `engines/kanagawa/config/routes.rb` atualizado com o esqueleto aninhado: `resources :parties`; `resources :organs do ... end` com sub-recursos vazios (apenas comentários `# TODO Onda N`) para cada recurso citado no plano — garante que `kanagawa.engine.organ_bank_accounts_path(id)` etc. resolvam sem 500.
- [ ] Todos os controllers placeholder para recursos **da Onda 1** (`PartiesController`, `OrgansController`, `OrganMembershipsController` via `MembersController`) existem com actions apenas de `index` renderizando "em desenvolvimento" localizado.
- [ ] Um script `bin/kanagawa-locale-stubs` (ou rake task `kanagawa:locales:stub`) gera um arquivo `config/locales/kanagawa.<locale>.yml` para **cada** locale presente em `config/locales/defaults/` do host, contendo apenas `<locale>:\n  kanagawa:\n    _meta:\n      stub: true\n` (placeholder) se ainda não existir. pt-BR e en são tratados como "populados" e **não** sobrescritos.
- [ ] O script é idempotente (rodar de novo não apaga traduções existentes).
- [ ] README atualizado com instrução de rodar o script e com a política de que pt-BR e en são **obrigatórios**, os demais começam stubbed.
- [ ] Teste de smoke que, para cada locale shipped, solicita `/b` e verifica que a resposta não contém a string `translation missing`.
- [ ] NavInjector continua funcionando e agora exibe o label traduzido por `I18n.locale`.
- [ ] Nenhuma alteração fora de `engines/kanagawa/`.

## Affected files

- `engines/kanagawa/config/routes.rb`
- `engines/kanagawa/app/controllers/kanagawa/parties_controller.rb` (novo, placeholder)
- `engines/kanagawa/app/controllers/kanagawa/organs_controller.rb` (novo, placeholder)
- `engines/kanagawa/app/controllers/kanagawa/members_controller.rb` (novo, placeholder)
- `engines/kanagawa/app/views/kanagawa/parties/index.html.erb` (placeholder i18n)
- `engines/kanagawa/app/views/kanagawa/organs/index.html.erb` (placeholder i18n)
- `engines/kanagawa/app/views/kanagawa/members/index.html.erb` (placeholder i18n)
- `engines/kanagawa/lib/tasks/kanagawa_locales.rake` (rake task `kanagawa:locales:stub`)
- `engines/kanagawa/config/locales/kanagawa.<locale>.yml` (gerados — um arquivo por locale do host)
- `engines/kanagawa/config/locales/kanagawa.pt-BR.yml` (expandido com chaves para as novas páginas)
- `engines/kanagawa/config/locales/kanagawa.en.yml` (expandido idem)
- `engines/kanagawa/README.md` (instruções da rake task)
- `engines/kanagawa/test/integration/routes_smoke_test.rb`

## Tests

- [ ] Smoke test percorre cada `I18n.available_locales` e acessa `/b`, `/b/parties`, `/b/organs` — resposta é 200/302 e não contém `translation missing`.
- [ ] `kanagawa:locales:stub` é idempotente (chamar 2x não altera arquivos existentes — verificado por hash de conteúdo).

## Out of scope

- Conteúdo real das páginas `parties`, `organs`, `members` — vira "em desenvolvimento" por enquanto. As implementações de negócio ficam nas issues #1, #2, #3 (modelos) e se integram ao UI apenas na Onda 1 *conclusion* ou na Onda 2.
- Tradução de fato para idiomas além de pt-BR e en — os stubs são escalonados para tradutores ao longo do tempo.

## Notes / references

- Host locales: listados em `config/locales/defaults/` (~110 arquivos).
- Convenção de chaves: tudo dentro de `kanagawa.<feature>.<key>`.
- O arquivo kanagawa.pt-BR.yml atual já tem `nav.label`, `home.heading`, `home.intro_html`, `home.roadmap_prompt`, `home.links.readme`, `home.links.roadmap_html` — esta issue expande para `parties.*`, `organs.*`, `members.*`.
