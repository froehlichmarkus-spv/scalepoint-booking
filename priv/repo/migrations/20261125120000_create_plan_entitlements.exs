defmodule Tymeslot.Repo.Migrations.CreatePlanEntitlements do
  use Ecto.Migration

  def change do
    create table(:plan_entitlements) do
      add(:user_id, references(:users, on_delete: :delete_all), null: false)
      add(:plan, :string, null: false, default: "free")
      add(:status, :string, null: false, default: "none")
      add(:interval, :string)
      add(:trial_ends_at, :utc_datetime)
      add(:current_period_end, :utc_datetime)
      add(:cancel_at_period_end, :boolean, null: false, default: false)
      add(:grace_until, :utc_datetime)
      add(:billing_account_ref, :string)
      add(:source_version, :bigint, null: false, default: 0)
      add(:show_badge_on_pro, :boolean, null: false, default: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:plan_entitlements, [:user_id]))
    create(index(:plan_entitlements, [:status]))

    create table(:plan_webhook_deliveries) do
      add(:event_id, :string, null: false)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:plan_webhook_deliveries, [:event_id]))
  end
end
