defmodule Tymeslot.Repo.Migrations.CreateSalesRooms do
  use Ecto.Migration

  def change do
    create table(:sales_rooms) do
      add :profile_id, references(:profiles, on_delete: :delete_all), null: false
      add :booking_page_id, references(:booking_pages, on_delete: :delete_all)
      add :meeting_type_id, references(:meeting_types, on_delete: :delete_all)
      add :scope_key, :string, null: false
      add :override, :boolean, null: false, default: false
      add :accent, :string
      add :blocks, {:array, :map}, null: false, default: []
      add :page_views, :integer, null: false, default: 0
      add :download_counts, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sales_rooms, [:scope_key])
    create index(:sales_rooms, [:profile_id])
    create index(:sales_rooms, [:meeting_type_id])
  end
end
