# [Onda 1] Estatuto partidário (item II)

## Manual citation

- Res. TSE nº 23.432/14, item **II** (Estatutos partidários)
- Res. TSE nº 23.432/14, item **VII.2** (normas de limite de gastos devem constar no estatuto)
- Lei nº 9.096/1995, art. 15 (conteúdo obrigatório do estatuto)

## Problem

O item II da Resolução exige que os estatutos contenham, entre outras matérias, **normas sobre finanças e contabilidade** (limites de contribuições dos filiados, limites de gastos dos candidatos, fontes de receita) e **critérios de distribuição do Fundo Partidário** entre as esferas. Para que o sistema possa validar operações futuras (por exemplo, limites de doação de filiado em Onda 3), essas regras precisam estar cadastradas por partido.

## Acceptance criteria

- [ ] Migration cria `kanagawa_party_statutes` com: `party_id:integer` (FK, único enquanto `effective_to IS NULL`), `version:string`, `effective_from:date`, `effective_to:date` (nullable — aberto), `member_contribution_limit_rule:text` (regra livre em texto), `candidate_spending_limit_rule:text`, `revenue_sources_rule:text`, `fundo_partidario_distribution_rule:text`, `source_document_url:string`, `source_document_filename:string`, timestamps.
- [ ] Índice único em `(party_id, version)`.
- [ ] Regra de negócio: no máximo 1 estatuto ativo (`effective_to IS NULL`) por partido por vez; ao criar um novo ativo, o anterior recebe `effective_to = Date.current - 1.day`.
- [ ] Model `Kanagawa::PartyStatute` `belongs_to :party`, scope `active`, `#activate!` transacional que fecha o anterior.
- [ ] Model validates presença de `effective_from`, `member_contribution_limit_rule`, `candidate_spending_limit_rule`, `revenue_sources_rule`, `fundo_partidario_distribution_rule`.
- [ ] Strings da UI via `t("kanagawa.party_statutes.*")` — pt-BR + en.
- [ ] Testes cobrindo ativação com fechamento do anterior, unicidade de versão, scope `active`.
- [ ] Nenhuma alteração fora de `engines/kanagawa/`.

## Affected files

- `engines/kanagawa/db/migrate/<ts>_create_kanagawa_party_statutes.rb`
- `engines/kanagawa/app/models/kanagawa/party_statute.rb`
- `engines/kanagawa/app/models/kanagawa/party.rb` (adicionar `has_many :statutes`, `has_one :active_statute`)
- `engines/kanagawa/config/locales/kanagawa.pt-BR.yml`
- `engines/kanagawa/config/locales/kanagawa.en.yml`
- `engines/kanagawa/test/models/kanagawa/party_statute_test.rb`
- `engines/kanagawa/test/fixtures/kanagawa/party_statutes.yml`

## Tests

- [ ] Criar novo estatuto ativo fecha o anterior com `effective_to` = ontem
- [ ] Não é possível ter 2 estatutos ativos simultaneamente
- [ ] Unicidade por versão

## Out of scope

- Upload e armazenamento do PDF do estatuto (ActiveStorage) — fica para issue separada em Onda 1 ou Onda 7
- Parsing automático do texto do estatuto — fora do escopo do sistema (regras são texto livre + campos estruturados futuros)
- Limites numéricos extraíveis (por exemplo, percentual máximo para candidato) — serão adicionados como campos estruturados quando forem necessários em Onda 3 / Onda 5

## Notes / references

- Manual TRE-SC, p. 8 (item II)
- O *what changed?* da Resolução destaca que o estatuto agora **deve** definir limites de gastos de campanha — dado crítico para validação em Onda 3.
