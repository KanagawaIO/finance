# [Onda 1] Partido e órgão partidário (hierarquia de cinco esferas)

## Manual citation

- Res. TSE nº 23.432/14, item **III** (obrigações em todos os níveis, inclusive comissões provisórias)
- Res. TSE nº 23.432/14, item **V** (contas bancárias por esfera)
- Res. TSE nº 23.432/14, item **XXIII** (esfera determina a quem apresentar as contas)
- Lei nº 9.096/1995, art. 15 (organização partidária)

## Problem

Toda funcionalidade futura — contas bancárias, doações, gastos, prestação de contas — opera no nível de um **órgão partidário**, não do partido abstrato. A engine precisa representar o partido (CNPJ raiz) e a hierarquia dos seus órgãos em cinco esferas (nacional → estadual → distrital → municipal → zonal), com a possibilidade de comissões provisórias (item III).

## Acceptance criteria

- [ ] Migration cria `kanagawa_parties` com: `cnpj:string` (único, 14 dígitos), `sigla:string` (único), `name:string`, `founded_on:date`, `tse_number:string`, timestamps.
- [ ] Migration cria `kanagawa_party_organs` com: `party_id:integer` (FK), `parent_id:integer` (FK self-join), `sphere:integer` (enum: `national=0`, `state=1`, `district=2`, `municipal=3`, `zonal=4`), `provisional:boolean default false`, `uf:string(2)` (nullable; obrigatório para state+), `city_ibge_code:string` (nullable; obrigatório para municipal), `zonal_number:integer` (nullable; obrigatório para zonal), `cnpj:string` (único — cada esfera tem seu próprio CNPJ), `name:string`, `active_from:date`, `active_to:date`, timestamps.
- [ ] Índices: `(party_id, sphere)`, `(parent_id)`, `(cnpj)` único.
- [ ] Regra: `national` não tem `parent_id`; `state` e `district` têm parent `national`; `municipal` tem parent `state` ou `district`; `zonal` tem parent `municipal`.
- [ ] Regra: exatamente um órgão `national` por `party_id` ativo.
- [ ] Validação de CNPJ (dígito verificador) via utilitário reutilizável em `Kanagawa::Cnpj.valid?`.
- [ ] Model `Kanagawa::Party` com associações `has_many :party_organs`, `has_one :national_organ`; validates CNPJ/sigla únicos.
- [ ] Model `Kanagawa::PartyOrgan` com enum `sphere`, `belongs_to :party`, `belongs_to :parent, class_name: "Kanagawa::PartyOrgan", optional: true`, `has_many :children`; métodos `#ancestors`, `#descendants`; validação de coerência parent/sphere.
- [ ] Seed de exemplo (apenas em test/development via fixtures) — **nunca** dados reais de partidos em produção.
- [ ] Testes cobrindo: criação de partido, hierarquia completa (nacional→estadual→municipal→zonal), rejeição de parent inválido, unicidade de nacional ativo.
- [ ] Strings da UI via `t("kanagawa.parties.*")` e `t("kanagawa.party_organs.spheres.*")` — pt-BR e en populadas.
- [ ] Nenhuma alteração fora de `engines/kanagawa/`.

## Affected files

- `engines/kanagawa/db/migrate/<ts>_create_kanagawa_parties.rb`
- `engines/kanagawa/db/migrate/<ts>_create_kanagawa_party_organs.rb`
- `engines/kanagawa/app/models/kanagawa/party.rb`
- `engines/kanagawa/app/models/kanagawa/party_organ.rb`
- `engines/kanagawa/lib/kanagawa/cnpj.rb` (utilitário)
- `engines/kanagawa/config/locales/kanagawa.pt-BR.yml`
- `engines/kanagawa/config/locales/kanagawa.en.yml`
- `engines/kanagawa/test/models/kanagawa/party_test.rb`
- `engines/kanagawa/test/models/kanagawa/party_organ_test.rb`
- `engines/kanagawa/test/fixtures/kanagawa/parties.yml`
- `engines/kanagawa/test/fixtures/kanagawa/party_organs.yml`

## Tests

- [ ] CNPJ inválido é rejeitado (dígito verificador)
- [ ] Hierarquia respeita regras de parent por esfera
- [ ] Impossível ter 2 nacionais ativos para o mesmo partido
- [ ] Fixtures servem de dados base para todas as próximas issues

## Out of scope

- Cadastro de estatuto partidário → **#3** (Onda 1)
- UI para gerenciar partidos e órgãos → **#4** (Onda 1, rota/layout)
- Integração com o registro oficial do partido no TSE → Onda 10

## Notes / references

- Manual TRE-SC, p. 9 (item III)
- Manual TRE-SC, p. 11 (item V — contas bancárias por esfera)
- Manual TRE-SC, p. 35 (item XXIII — a quem apresentar as contas por esfera)
