# CLAUDE.md — Kanagawa engine

Engine-specific guidance layered on top of the root `CLAUDE.md`. Read this before touching any file under `engines/kanagawa/`.

## Non-negotiables

- **Zero-conflict with upstream Sure.** The root CLAUDE.md and every file outside `engines/kanagawa/` is upstream territory. Never modify them. Verify with:
  ```bash
  git diff main -- . ':!engines/kanagawa/'   # must print nothing
  ```
- **pt-BR primary, multilingual always.** Every user-facing string goes through `t("kanagawa.*")`. TSE terminology (Fundo Partidário, prestação de contas, etc.) stays in Portuguese across locales. Only `engines/kanagawa/roadmap.html` is pt-BR-only.
- **Domain rule citations.** Every commit that implements a TSE rule cites the manual section in its message: `Ref. Res. TSE 23.432/14 <item>`.

## Integration gotchas (learned the hard way)

### 1. URL helpers do not cross the `isolate_namespace` boundary

`Kanagawa::Engine` uses `isolate_namespace Kanagawa`. Inside engine controllers and views, bare path helpers like `transactions_path`, `root_path`, `new_registration_path` behave unpredictably:

- **Undefined** in engine view contexts — the host layout/partials that call them raise `undefined local variable or method 'transactions_path'`.
- **Inherited-but-broken** in engine controllers — helpers like `new_registration_path` are inherited from `::ApplicationController` but their internal `url_for` resolves against the engine's isolated router and raises `UrlGenerationError: No route matches {...}`.

**Solution already in place** — `Kanagawa::MainAppRouteDelegator` at `app/controllers/kanagawa/main_app_route_delegator.rb`:

- `method_missing` + `respond_to_missing?` catch any `*_path` / `*_url` that the engine's route table doesn't define and forward to `main_app`. Covers the view-context case.
- Explicit shadowing (`HOST_CONTROLLER_HELPERS` list + `root_path/root_url` overrides) for helpers defined in *both* route tables or inherited via `Rails.application.routes.url_helpers`. Covers the controller-context case.

Included in `Kanagawa::ApplicationController` **and** `Kanagawa::ApplicationHelper`. If a new host concern or partial adds a path helper that breaks under `/b`, add it to `HOST_CONTROLLER_HELPERS` — don't try to patch the concern.

### 2. Engine helpers do not auto-mix into engine views

`isolate_namespace` turns off the host's `helper :all`. `app/helpers/kanagawa/*.rb` are loaded by Zeitwerk but not included in the engine's view context until you ask:

```ruby
# app/controllers/kanagawa/application_controller.rb
helper "kanagawa/dashboard"        # string form — defers autoload
helper Kanagawa::ApplicationHelper # also fine
```

Register each helper explicitly. Symptom when you forget: `undefined method 'kanagawa_brl'` (or whatever) during template rendering.

### 3. Zeitwerk collapses `concerns/` only at the *host* top level

Rails auto-collapses `app/controllers/concerns/` and `app/models/concerns/` so `app/controllers/concerns/foo.rb` defines `Foo`, not `Concerns::Foo`. **Engines do not get this collapse automatically.** A file at `app/controllers/kanagawa/concerns/foo.rb` inside the engine resolves to `Kanagawa::Concerns::Foo`.

Symptom: production boot fails with `NameError: uninitialized constant Kanagawa::Foo` during `rails assets:precompile`. The dev environment may not surface this because eager-loading is off.

**Rule**: don't put engine mixin modules under a `concerns/` subdirectory. Place them directly under `app/controllers/kanagawa/` (or wherever), and let the module name match the path exactly.

### 4. Filter-ordering is unreliable for boot-time-registered callbacks

`Kanagawa::NavInjector` is mixed into `ActionController::Base` via `ActiveSupport.on_load(:action_controller_base)` at boot — **before** Sure's `ApplicationController` includes the `Localize` concern. Result: NavInjector's `after_action :inject_kanagawa_nav` is registered earlier in the filter chain than `Localize`'s `around_action :switch_locale`. Rails runs earlier-registered after-filters *outside* later around-filters, so by the time `inject_kanagawa_nav` fires, `I18n.with_locale(user_locale) { ... }` has already closed and `I18n.locale` is back to `:en`.

**Rule**: in boot-time-registered filters (NavInjector and anything added the same way in future), **do not rely on `I18n.locale`, `Time.zone`, `Current.*` side effects, or anything else a host `around_action` might set up**. Compute what you need directly. For the locale specifically, use `kanagawa_effective_locale` in NavInjector, which reads `Current.user.locale` / `Current.family.locale` and passes it as the `locale:` option to `I18n.t`.

### 5. Engine-local SQLite stays isolated from the host Postgres

`Kanagawa::ApplicationRecord` calls `establish_connection` to `storage/kanagawa.sqlite3`. Two consequences:

- **No `belongs_to` / `has_many` across DBs.** Any cross-database association (e.g. `Kanagawa::OrganMembership` → host `User`) stores the host PK as a plain integer column and resolves in Ruby (`::User.find_by(id: user_id)`), never via Active Record association.
- **Migrations live in engine only.** `lib/kanagawa/engine.rb` adds `engines/kanagawa/db/migrate/` to the host's migration paths at boot, so `bin/rails db:migrate` runs them. Don't add anything to host `db/migrate/`.

### 6. Dokploy deploys on every push to `origin/main`

There is no staging; a broken commit becomes a broken prod in ~2 minutes. The build runs `SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile` which eager-loads the whole app — **any constant-resolution error surfaces at build time** (this is actually useful; Zeitwerk mismatches fail the build before the container starts). No local Ruby available: linting / syntax validation rely on the build.

### 7. LFS and the public-fork trap

The root `.gitattributes` marks `*.pdf` as LFS. **GitHub blocks LFS uploads to public forks** — `git push` fails with "can not upload new objects to public fork …". `engines/kanagawa/.gitignore` already lists `manual-*.pdf` for this reason. Don't commit PDFs (or any LFS-tracked binaries) from the engine. Source manuals live locally; their content is distilled into `README.md`, `roadmap.html`, and the issue bodies with per-commit citations.

## File map (current engine state)

| File | Role |
|---|---|
| `lib/kanagawa.rb` | Explicit `require "kanagawa/nav_injector"` before `"kanagawa/engine"` (nav injector is autoloaded from `lib/`, not `app/`). |
| `lib/kanagawa/engine.rb` | `isolate_namespace Kanagawa`, migrations path, `on_load` nav-injection include. |
| `lib/kanagawa/nav_injector.rb` | `after_action` that rewrites the HTML response to append the "Partidos" `<li>` to the sidebar `<ul class="space-y-0.5">`. Uses `kanagawa_effective_locale`. |
| `app/controllers/kanagawa/application_controller.rb` | Includes `MainAppRouteDelegator`, registers engine helpers. |
| `app/controllers/kanagawa/main_app_route_delegator.rb` | The generic + explicit URL-helper delegation module. |
| `app/controllers/kanagawa/home_controller.rb` | `/b` entry point — currently a mocked dashboard. Replace with real queries when Milestone 1 models exist. |
| `app/helpers/kanagawa/application_helper.rb` | Includes `MainAppRouteDelegator` for the view-context side. |
| `app/helpers/kanagawa/dashboard_helper.rb` | `kanagawa_brl`, `kanagawa_pct`, `kanagawa_relative_date`, `kanagawa_severity_classes`, `kanagawa_obligation_status`. |
| `app/views/kanagawa/home/index.html.erb` | The mocked dashboard view. |
| `app/models/kanagawa/application_record.rb` | SQLite `establish_connection`. All engine models inherit from this. |
| `config/locales/kanagawa.<locale>.yml` | Engine translations. pt-BR + pt + en populated; other host locales stubbed as part of issue #4. |
| `config/routes.rb` | `root "home#index"` only. Future resources go here. |
| `README.md` | Technical roadmap with 48-issue breakdown (10 milestones). |
| `roadmap.html` | pt-BR non-coder presentation of the roadmap. |
| `.github/ISSUE_TEMPLATE/domain_issue.md` | Template for every domain issue (manual citation + acceptance criteria + affected files + tests). |

## When working in the engine

- Use `Current.user` / `Current.family` directly — they're inherited from host `ApplicationController`.
- Use host Tailwind tokens (`text-primary`, `bg-container`, `bg-surface-hover`, `border-primary`, `text-subdued`, semantic `text-destructive/success/warning`). Never introduce new tokens in engine CSS.
- Prefer raw inline SVG (matching `NavInjector`'s pattern) over the host `icon` helper for now — we haven't confirmed which Lucide names are registered, and the injector context can't call helpers anyway.
- For new domain issues, follow `.github/ISSUE_TEMPLATE/domain_issue.md` exactly. Always include manual citation + acceptance criteria + affected files + tests.
- When scope grows beyond the engine boundary (e.g. "we need to patch `Localize`"), stop and design a workaround that stays inside `engines/kanagawa/`. The engine is meant to be additive-only.
