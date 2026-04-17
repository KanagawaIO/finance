# Kanagawa Engine

Mountable Rails engine that implements **full annual accountability for Brazilian political parties** (*prestação de contas anual de partidos políticos*) per **Resolução TSE nº 23.432/14**, on top of the Sure personal finance app.

Designed for **zero-conflict upstream syncing** — all custom code lives inside this directory, completely isolated from the Sure codebase.

## Mission & Scope

This engine targets party treasurers, accountants, fiscal councils, lawyers, and presidents of any sphere (*nacional / estadual / distrital / municipal / zonal*, including provisional commissions). The domain rules are sourced from the two TRE-SC manuals under `manual-1-20.pdf` / `manual-21-34.pdf` and the underlying resolution itself. Every domain commit cites its manual section (e.g. `Ref. Res. TSE 23.432/14 XXIV.k`).

**Status**: scaffolding — **Milestone 0 (engine bootstrap) complete**, Milestone 1 issues live on GitHub ([#1](../../issues/1), [#2](../../issues/2), [#3](../../issues/3), [#4](../../issues/4)). No domain models yet. See the [Roadmap](#roadmap).

### Two audiences, two roadmap artifacts

| Artifact | Audience | Format |
|----------|----------|--------|
| This README — [Roadmap](#roadmap) | engineers, contributors | markdown + GitHub issue links |
| [`roadmap.html`](./roadmap.html) | party treasurers, accountants, non-technical stakeholders | standalone pt-BR HTML, opens in any browser |

## Architecture

- **Mount point**: `/b`
- **Database**: Separate SQLite (`storage/kanagawa.sqlite3`), independent of Sure's PostgreSQL
- **Layout**: Shares Sure's application layout — pages look native
- **Auth**: Inherits `Current.user`, `Current.family`, and all Sure authentication
- **Nav**: Injects a "Business" item into the sidebar via `after_action` (no layout file changes)

## What the Engine CAN Do

All of these require **zero changes** to Sure's codebase:

- **Add new pages** — controllers, views, and routes under `/b/*`
- **Add new database tables** — engine migrations create tables in its own SQLite database
- **Read Sure's data** — query `Account`, `Transaction`, `Family`, etc. directly from PostgreSQL
- **Share Sure's UI** — use the same layout, design system CSS tokens, Tailwind classes, `icon` helper
- **Add Stimulus controllers** — engine-specific JS controllers auto-registered via importmap
- **Add ViewComponents** — engine-specific components in `app/components/kanagawa/`
- **Add background jobs** — engine jobs run in Sidekiq alongside Sure's jobs
- **Add helpers** — engine helpers available in engine views

## What the Engine CANNOT Do Directly

These would require modifying Sure's source files:

- Modify existing Sure pages or controller behavior
- Add columns to Sure's PostgreSQL tables
- Change Sure's model validations, callbacks, or associations
- Modify Sure's navigation HTML (handled by `NavInjector` instead)
- SQL JOIN between engine SQLite tables and Sure's PostgreSQL tables

## Workarounds for Deeper Integration

When you need to react to Sure's data without touching its code, use these patterns (ordered from simplest to most decoupled):

### Pattern A: Read Sure's PostgreSQL Directly (Recommended)

Engine controllers inherit from `::ApplicationController`, so all Sure models are available. This is the simplest and most common pattern.

```ruby
class Kanagawa::ReportsController < Kanagawa::ApplicationController
  def index
    # Read from Sure's PostgreSQL
    @accounts = Current.family.accounts.active
    @transactions = Current.family.transactions.where(date: 30.days.ago..)

    # Combine with engine's own SQLite data
    @custom_metrics = Kanagawa::Metric.where(family_id: Current.family.id)
  end
end
```

### Pattern B: Subscribe to ActiveSupport::Notifications

Sure instruments events in some areas (e.g., `simplefin.*` events). The engine can subscribe without touching Sure:

```ruby
# In engines/kanagawa/lib/kanagawa/engine.rb
initializer "kanagawa.event_subscribers" do
  ActiveSupport::Notifications.subscribe(/simplefin\./) do |name, start, finish, id, payload|
    Kanagawa::EventLog.create!(event_name: name, payload: payload.to_json)
  end
end
```

### Pattern C: Inject ActiveRecord Callbacks

The engine can register `after_commit` observers on Sure's models at boot time, without modifying the model files:

```ruby
# In engines/kanagawa/lib/kanagawa/engine.rb
config.to_prepare do
  Transaction.after_commit :notify_kanagawa, on: [:create, :update]
  Transaction.define_method(:notify_kanagawa) do
    Kanagawa::TransactionWatcher.process(self)
  end
end
```

**Use sparingly.** If upstream renames `Transaction`, this will raise a visible error at boot. But it's a clean way to react to Sure's data changes without modifying Sure files.

### Pattern D: Consume Sure's REST API

Sure exposes a full API at `/api/v1/`. The engine can call it as an internal client for maximum decoupling:

```ruby
response = Faraday.get(
  "http://localhost:3000/api/v1/accounts",
  nil,
  { "X-Api-Key" => api_key }
)
accounts = JSON.parse(response.body)
```

This is the loosest coupling — the engine could even be extracted to a separate service later.

### Pattern E: Background Jobs That Poll Sure's Data

Schedule periodic Sidekiq jobs that read Sure's PostgreSQL and sync into the engine's SQLite:

```ruby
class Kanagawa::SyncFromSureJob < ApplicationJob
  def perform
    Family.find_each do |family|
      accounts = family.accounts.includes(:balances).to_a
      Kanagawa::AccountSnapshot.upsert_from(accounts)
    end
  end
end
```

### Pattern F: Listen to Turbo Streams

Sure broadcasts Turbo Streams on sync completion (`broadcast_refresh`, `broadcast_replace_to`). Engine views can subscribe to the same channels for live updates:

```erb
<%= turbo_stream_from Current.family %>
<%# This view auto-refreshes when Sure broadcasts a sync completion %>
```

## Adding a New Page

1. Create a controller:
   ```ruby
   # engines/kanagawa/app/controllers/kanagawa/reports_controller.rb
   module Kanagawa
     class ReportsController < ApplicationController
       def index
         @accounts = Current.family.accounts.active
       end
     end
   end
   ```

2. Create a view:
   ```erb
   <%# engines/kanagawa/app/views/kanagawa/reports/index.html.erb %>
   <h1>Custom Reports</h1>
   <% @accounts.each do |account| %>
     <p><%= account.name %>: <%= account.balance %></p>
   <% end %>
   ```

3. Add the route:
   ```ruby
   # engines/kanagawa/config/routes.rb
   Kanagawa::Engine.routes.draw do
     resources :reports, only: [:index, :show]
   end
   ```

4. **Zero changes to any Sure file.** Visit `/b/reports` to see your page.

## Adding an Engine Model (SQLite)

1. Create a migration:
   ```ruby
   # engines/kanagawa/db/migrate/20260416000000_create_kanagawa_metrics.rb
   class CreateKanagawaMetrics < ActiveRecord::Migration[7.2]
     def change
       create_table :kanagawa_metrics do |t|
         t.integer :family_id, null: false
         t.string :name, null: false
         t.decimal :value
         t.timestamps
       end
     end
   end
   ```

2. Create the model:
   ```ruby
   # engines/kanagawa/app/models/kanagawa/metric.rb
   module Kanagawa
     class Metric < ApplicationRecord
       # Inherits SQLite connection from Kanagawa::ApplicationRecord
     end
   end
   ```

3. Run `bin/rails db:migrate` — the migration runs against SQLite.

## Localization (i18n)

The engine is **fully multilingual** — it must support every locale the Sure host supports. Sure ships ~110 locale files under `config/locales/defaults/` plus custom keys across `models/`, `views/`, `mailers/`, `breadcrumbs/`.

### Rules
- Every user-facing string goes through `t("kanagawa.<feature>.<key>")` — **never** hardcoded.
- The `kanagawa.*` i18n namespace is exclusive to this engine.
- Primary translation: **pt-BR** (domain is Brazilian). Fallback: **en**.
- TSE terminology (*Fundo Partidário*, *prestação de contas*, *sobras de campanha*, *impugnação*, *parecer conclusivo*, etc.) is kept in Portuguese across locales where no natural equivalent exists, with a translator comment.

### Files
- `config/locales/kanagawa.pt-BR.yml` — populated (primary)
- `config/locales/kanagawa.en.yml` — populated (fallback)
- `config/locales/kanagawa.<locale>.yml` for other host-supported locales — stubbed during Milestone 1 (issue #4), filled by translators over time.

### Exception
`roadmap.html` is **pt-BR only** — its audience is Brazilian party treasurers/stakeholders.

## Roadmap

The system ships in **10 waves (milestones)**. Each bullet below becomes a dedicated GitHub issue with: **manual citation**, **acceptance criteria**, **affected files**, **tests**. Issue numbers below are placeholders until the issues are created.

Legend: ✅ done · 🚧 in progress · ⬜ not started

### 🚧 Milestone 1 — Foundation
- [#1](../../issues/1) Engine-local role model (`Kanagawa::OrganMembership`) linking host `User.id` to `PartyOrgan` with role enum
- [#2](../../issues/2) `Party` + `PartyOrgan` hierarchy (5 spheres: `national|state|district|municipal|zonal`, provisional flag, parent chain)
- [#3](../../issues/3) `PartyStatute` persistence (Art II — finance rules + Fundo Partidário distribution criteria)
- [#4](../../issues/4) `/b` route tree skeleton + layout inheritance + locale stubs for all host-supported languages

### ⬜ Milestone 2 — Banking & donors
- `#5` Segregated `BankAccount` typing: `fundo_partidario | doacoes_campanha | outros_recursos` (Lei 9.096/95 art. 43)
- `#6` Monthly `BankStatement` + `BankStatementEntry` ingestion (XXIV.e — no provisional statements)
- `#7` `Donor` registry with CPF/CNPJ validation (pt-BR format)
- `#8` Forbidden-source classifier (XI — 14 categories) + authority concept (XI.1) + indirect-donation chain (XI.2)

### ⬜ Milestone 3 — Donations & receipts
- `#9` Financial `Donation` with nominative check / identified transfer rule (VII.1, art. 39 §3º)
- `#10` In-kind `Donation` (estimável) with market valuation + evidence types (VIII)
- `#11` Sequential `DonationReceipt` with TSE portal number (X) — 15 days (financial) / 5 days (in-kind)
- `#12` `DonationRefusal` with last-business-day-of-month+1 reversal window (X.1)
- `#13` Election-year donation limits — 2% PJ / 10% PF / R$ 50k in-kind exemption (VII.2)
- `#14` Internet fundraising (VI) — card capture, chargeback tracking

### ⬜ Milestone 4 — Unidentified & forbidden recollections
- `#15` `UnidentifiedResource` detector (XII — 3 conditions) + GRU recollection
- `#16` `ForbiddenSourceIncident` reversal window (XIII — last business day of month+1)

### ⬜ Milestone 5 — Expenses (Gastos)
- `#17` `Expense` categorization (XV — 5 permitted Fundo Partidário categories)
- `#18` Payment-method enforcement (XVI — nominative crossed check / identified bank transaction)
- `#19` `PettyCash` (Fundo de Caixa) — R$ 5.000 cap, R$ 400 per-item, ≤ 2%/yr, no fractioning (XVII)
- `#20` `PersonnelLimit` — 50% cap per sphere, excludes autonomous + taxes (XIX)
- `#21` `Foundation` allocation — 20% min for national, 15-day credit, reversion rules (XVIII)
- `#22` `WomensProgramAllocation` — 5% min per sphere + carryover + 2.5% penalty (XX)
- `#23` `ObligationAssumption` — formal agreement, Fundo Partidário restriction (XXI)

### ⬜ Milestone 6 — Sobras & Comercialização
- `#24` `CampaignSurplus` — financial + non-financial (XIV)
- `#25` `FundraisingEvent` / `ProductSale` with 5-business-day notification (IX)

### ⬜ Milestone 7 — Annual accountability report
- `#26` SPED submission stub + TSE chart of accounts (XXII)
- `#27` `AnnualReport` composition — 22 pieces a–v (XXIV)
- `#28` Demonstratives generation (XXIV items j–r, p: FP recebidos/distribuídos, doações, obrigações, dívidas de campanha, receitas-gastos, transferências eleitorais, contribuições, sobras, fluxos de caixa)
- `#29` Submission workflow — April 30 deadline, recipient routing (XXIII)
- `#30` Monthly bookkeeping in election years — SPED by 15th business day (XXIII)
- `#31` Digital signatures chain — president / treasurer / lawyer / accountant (XXIV)

### ⬜ Milestone 8 — Adjudication & sanctions
- `#32` `Proceeding` state machine (XXVI)
- `#33` Omissão workflow — 72h notification + 5d citation (XXV)
- `#34` Preliminary + proper technical examination (XXVIII.1–2)
- `#35` `Diligencia` workflow — 30d party, sigilo fiscal judicial (XXVIII.3)
- `#36` `Impugnacao` handling — filed by MPE or party (XXVI)
- `#37` `ParecerConclusivo` generation — receitas/gastos totals, impropriedades, irregularidades (XXVIII.4)
- `#38` `Judgment` outcomes — approved / with caveats / partial / disapproved / not presented (XXIX)
- `#39` `Sanction` — Fundo Partidário suspension proportional 1–12 months (XXX)
- `#40` `Appeal` (XXXI) + `ReviewRequest` (XXXII) + `Regularization` (XXXIII)
- `#41` `DecisionExecution` — GRU, Cadin, AGU referral (XXXIV)

### ⬜ Milestone 9 — Lifecycle (fusion / incorporation / extinction)
- `#42` `PartyFusion` accountability flow (XXXV.1)
- `#43` `PartyIncorporation` accountability flow (XXXV.2)
- `#44` `PartyExtinction` — Fundo Partidário return + União patrimony transfer (XXXV.3)

### ⬜ Milestone 10 — TSE / Receita / DJE integrations
- `#45` TSE *plano de contas específico* loader (XXII)
- `#46` TSE portal integration — receipt numbering (X) + complementary-pieces upload (XXIV)
- `#47` DJE / *imprensa oficial* publication hooks (XXVI)
- `#48` SPED / Receita Federal integration — digital bookkeeping submission (XXII, III.3)

### Delivery-order rationale

- **M1–M2** first because nothing exists without parties, organs, bank accounts, donors.
- **M3** precedes expenses: donations are the primary revenue with the tightest TSE deadlines (15-day receipts, election-year limits).
- **M4** is small and blocks M7 (the annual report must attach GRU copies).
- **M5** (expenses) before M7 so the annual report has real data.
- **M6** is low-cost and closes the revenue side.
- **M7** composes everything into the April 30 submission.
- **M8** models the judicial rite that follows submission.
- **M9** handles the edge cases (fusion / extinction) — not needed to clear a regular year.
- **M10** is the external integration layer — deliberately last, replacing local mocks with real TSE / Receita / DJE endpoints once internal flows are proven.

## Contributing

### Issue template
New domain issues should follow [`.github/ISSUE_TEMPLATE/domain_issue.md`](./.github/ISSUE_TEMPLATE/domain_issue.md) (created alongside the first Milestone 1 issues). Required sections:
- **Manual citation** (e.g. *Res. TSE 23.432/14 XXIV.k*)
- **Acceptance criteria** (checklist of observable behaviours)
- **Affected files** (inside `engines/kanagawa/` only)
- **Tests** (Minitest + fixtures, per host convention)

### Running tests
```bash
bin/rails test engines/kanagawa/test/
bin/rubocop engines/kanagawa/
bin/brakeman --no-pager
```

### Zero-conflict guarantee
Before committing, verify no host files are touched:
```bash
git diff main -- . ':!engines/kanagawa/'
# should print nothing
```

## Upstream Sync

- A GitHub Action (`.github/workflows/sync-upstream.yml`) runs daily to auto-merge upstream changes
- If the merge fails, it creates a GitHub Issue with the conflicting files listed
- A self-heal script ensures the `gem "kanagawa"` line stays at the end of `Gemfile` to prevent conflicts
- Only 2 lines in Sure's codebase reference this engine (`Gemfile` + `config/routes.rb`)
