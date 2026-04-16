# Kanagawa Engine

Mountable Rails engine for custom extensions to the Sure personal finance app. Designed for **zero-conflict upstream syncing** — all custom code lives inside this directory, completely isolated from the Sure codebase.

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

## Upstream Sync

- A GitHub Action (`.github/workflows/sync-upstream.yml`) runs daily to auto-merge upstream changes
- If the merge fails, it creates a GitHub Issue with the conflicting files listed
- A self-heal script ensures the `gem "kanagawa"` line stays at the end of `Gemfile` to prevent conflicts
- Only 2 lines in Sure's codebase reference this engine (`Gemfile` + `config/routes.rb`)
