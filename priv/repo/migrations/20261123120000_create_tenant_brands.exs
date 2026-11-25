defmodule Tymeslot.Repo.Migrations.CreateTenantBrands do
  use Ecto.Migration

  def change do
    create table(:tenant_brands, primary_key: false) do
      add :key, :string, primary_key: true, null: false
      add :document, :map, null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
