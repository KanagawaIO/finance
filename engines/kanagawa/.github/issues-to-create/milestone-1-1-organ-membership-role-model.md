# [Onda 1] Modelo de papéis no órgão partidário (OrganMembership)

## Manual citation

- Res. TSE nº 23.432/14, item **III** (obrigações dos partidos)
- Res. TSE nº 23.432/14, item **XXIV**, alínea **i** (relação identificando presidente, tesoureiro e responsáveis pela movimentação financeira)
- Res. TSE nº 23.432/14, item **XXIV** (assinaturas digitais nas peças complementares)

## Problem

A engine precisa representar quem é responsável pela movimentação financeira de um órgão partidário (presidente, tesoureiro, contador, advogado, conselho fiscal), sem alterar o modelo `User` do aplicativo Sure (zero-conflito). Esse cadastro é pré-requisito para: emissão de recibos, composição da prestação de contas (item XXIV.i) e assinatura digital das peças complementares.

## Acceptance criteria

- [ ] Migration cria `kanagawa_organ_memberships` no SQLite da engine com colunas: `user_id:integer` (FK opaca para `host.User.id`, **sem** alteração de schema no host), `party_organ_id:integer` (FK), `role:string` (enum: `president`, `treasurer`, `accountant`, `lawyer`, `fiscal_council`), `active_from:date`, `active_to:date`, `notes:text`, timestamps.
- [ ] Índices: `(user_id)`, `(party_organ_id, role)`, unicidade parcial em `(party_organ_id, role)` enquanto `active_to IS NULL` para `president` e `treasurer`.
- [ ] Model `Kanagawa::OrganMembership` com enum `role`, validates `user_id`, `party_organ_id`, `role`, `active_from`; scope `active` (where `active_to IS NULL OR active_to >= Date.current`).
- [ ] Método `#user` resolve dinamicamente via `::User.find_by(id: user_id)` — nunca via `belongs_to` com `foreign_key` cross-database.
- [ ] Regra de negócio: um órgão tem no máximo 1 `president` e 1 `treasurer` ativo por vez.
- [ ] Todas as strings para a UI via `t("kanagawa.roles.*")` — populadas em pt-BR e en.
- [ ] Testes Minitest cobrindo: criação feliz, validação de obrigatórios, unicidade de president/treasurer ativos, scope `active`, resolução de `user` cross-database.
- [ ] Nenhuma alteração fora de `engines/kanagawa/` (verificado por `git diff main -- . ':!engines/kanagawa/'`).

## Affected files (inside `engines/kanagawa/` only)

- `engines/kanagawa/db/migrate/<timestamp>_create_kanagawa_organ_memberships.rb`
- `engines/kanagawa/app/models/kanagawa/organ_membership.rb`
- `engines/kanagawa/config/locales/kanagawa.pt-BR.yml` (chaves `kanagawa.roles.*`)
- `engines/kanagawa/config/locales/kanagawa.en.yml` (mesmas chaves)
- `engines/kanagawa/test/models/kanagawa/organ_membership_test.rb`
- `engines/kanagawa/test/fixtures/kanagawa/organ_memberships.yml`

## Tests

- [ ] `organ_membership_test.rb`: cria ativo, valida campos, testa unicidade, testa `active` scope
- [ ] Testa que `#user` funciona mesmo com `User` morando em banco diferente (Postgres host) e o `OrganMembership` em SQLite
- [ ] Todas as mensagens de erro via i18n (`errors.messages.*` já fornece muitas — verificar que as customizadas estão no `kanagawa.*`)

## Out of scope

- UI de gerenciamento de membros (`/b/organs/:id/members`) fica para **#4** (Onda 1, rota/layout) ou próxima Onda.
- Associação entre membership e assinaturas digitais (será tratado na Onda 7, item XXIV).
- Autorização por papel (policy/CanCan) — fica para Onda 1 issue de rota, ou isolada posteriormente.

## Notes / references

- Manual TRE-SC, p. 9 (item III — obrigações)
- Manual TRE-SC, p. 37 (item XXIV.i — identificação do presidente, tesoureiro, responsáveis)
- Arquitetura: a FK `user_id` é opaca, resolvida em runtime. Nunca usar `belongs_to :user, foreign_key: :user_id` porque `User` está em Postgres e `OrganMembership` em SQLite — ActiveRecord não faz JOIN entre conexões.
