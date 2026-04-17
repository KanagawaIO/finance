module Kanagawa
  class HomeController < ApplicationController
    # Entry point of the engine at "/b".
    #
    # This action renders a **mocked** dashboard built from hard-coded data
    # structures. No database reads, no models, no external calls. Its purpose
    # is to demonstrate the TSE accountability domain visually before the
    # domain models land (see Milestones 1-7 in engines/kanagawa/README.md).
    #
    # When Milestone 1 ships, replace the mock_* assignments below with real
    # queries scoped by Current.user's OrganMembership.
    def index
      @mock_banner = true
      @today = Date.current
      @fiscal_year = 2025

      @organ = mock_organ
      @annual_report = mock_annual_report
      @bank_accounts = mock_bank_accounts
      @fundo_received_cents, @fundo_obligations = mock_fundo_obligations
      @pending_actions = mock_pending_actions
      @recent_activity = mock_recent_activity
      @upcoming_deadlines = mock_upcoming_deadlines
    end

    private
      def mock_organ
        Struct.new(:party_name, :party_sigla, :organ_name, :sphere, :cnpj, :uf, keyword_init: true).new(
          party_name: "Partido Exemplar",
          party_sigla: "PEX",
          organ_name: "Diretório Estadual de São Paulo",
          sphere: :state,
          cnpj: "12.345.678/0001-90",
          uf: "SP"
        )
      end

      def mock_annual_report
        Struct.new(:year, :status, :pieces_completed, :pieces_total, :deadline, keyword_init: true).new(
          year: @fiscal_year,
          status: :draft,
          pieces_completed: 14,
          pieces_total: 22,
          deadline: Date.new(2026, 4, 30)
        )
      end

      def mock_bank_accounts
        row = Struct.new(:kind, :balance_cents, :bank, :agency, :number, keyword_init: true)
        [
          row.new(kind: :fundo_partidario, balance_cents: 124_532_000, bank: "Banco do Brasil", agency: "1234-5", number: "67890-1"),
          row.new(kind: :doacoes_campanha, balance_cents:   8_745_000, bank: "Banco do Brasil", agency: "1234-5", number: "67891-0"),
          row.new(kind: :outros_recursos,  balance_cents:   2_378_000, bank: "Banco do Brasil", agency: "1234-5", number: "67892-8")
        ]
      end

      def mock_fundo_obligations
        received = 380_000_000 # R$ 3.800.000,00 in the fiscal year
        row = Struct.new(:key, :required_pct, :applied_cents, :target_cents, :manual_ref, :cap, keyword_init: true)
        obligations = [
          row.new(key: :fundacao, required_pct: 20.0, applied_cents: 64_000_000, target_cents: 76_000_000, manual_ref: "XVIII", cap: false),
          row.new(key: :mulheres, required_pct:  5.0, applied_cents:  9_500_000, target_cents: 19_000_000, manual_ref: "XX",     cap: false),
          row.new(key: :pessoal_cap, required_pct: 50.0, applied_cents: 145_000_000, target_cents: 190_000_000, manual_ref: "XIX", cap: true)
        ]
        [ received, obligations ]
      end

      def mock_pending_actions
        row = Struct.new(:key, :severity, :manual_ref, :deadline, :count, :amount_cents, keyword_init: true)
        [
          row.new(key: :pending_receipts,        severity: :warning,     manual_ref: "X",            deadline: @today + 7,  count: 12),
          row.new(key: :unidentified_gru,        severity: :destructive, manual_ref: "XII, XIII",    deadline: @today + 14, amount_cents: 420_000),
          row.new(key: :forbidden_reversal,      severity: :destructive, manual_ref: "XI, XIII",     deadline: @today + 14, count: 1),
          row.new(key: :monthly_bookkeeping,     severity: :warning,     manual_ref: "XXIII",        deadline: @today - 1),
          row.new(key: :annual_report_pieces,    severity: :warning,     manual_ref: "XXIV",         deadline: @today + 14, count: 8)
        ]
      end

      def mock_recent_activity
        row = Struct.new(:kind, :direction, :amount_cents, :counterparty, :when, keyword_init: true)
        [
          row.new(kind: :donation_financial,       direction: :in,  amount_cents:    500_000, counterparty: "João da Silva (CPF 123.***.***-44)", when: @today - 1),
          row.new(kind: :expense,                  direction: :out, amount_cents:  1_250_000, counterparty: "Folha de pagamento - março/2026",    when: @today - 2),
          row.new(kind: :donation_estimable,       direction: :in,  amount_cents:    300_000, counterparty: "Cessão temporária de veículo",       when: @today - 3),
          row.new(kind: :fundo_partidario_inflow,  direction: :in,  amount_cents: 12_500_000, counterparty: "Cota mensal do Fundo Partidário",    when: @today - 5),
          row.new(kind: :receipt_issued,           direction: nil,  amount_cents:    200_000, counterparty: "Recibo #0042 — Alpha Ltda (CNPJ)",   when: @today - 6)
        ]
      end

      def mock_upcoming_deadlines
        row = Struct.new(:key, :date, :manual_ref, keyword_init: true)
        [
          row.new(key: :annual_report,                 date: Date.new(2026, 4, 30), manual_ref: "XXIII"),
          row.new(key: :bank_statements_april,         date: Date.new(2026, 5, 30), manual_ref: "V.1"),
          row.new(key: :monthly_bookkeeping_election,  date: Date.new(2026, 6, 15), manual_ref: "XXIII"),
          row.new(key: :foundation_allocation_review,  date: Date.new(2026, 12, 31), manual_ref: "XVIII")
        ]
      end
  end
end
