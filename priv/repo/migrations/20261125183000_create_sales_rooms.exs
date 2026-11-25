defmodule Tymeslot.Repo.Migrations.CreateSalesRooms do
  use Ecto.Migration

  def change do
    create table(:sales_rooms) do
      add(:profile_id, references(:profiles, on_delete: :delete_all), null: false)
      add(:booking_page_id, references(:booking_pages, on_delete: :delete_all))
      add(:meeting_type_id, references(:meeting_types, on_delete: :delete_all))

      # profile:page:event, with 0 for an absent page or event type.
      add(:scope_key, :string, null: false)
      add(:document, :map, null: false, default: %{})

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:sales_rooms, [:scope_key]))
    create(index(:sales_rooms, [:profile_id]))
    create(index(:sales_rooms, [:booking_page_id]))
    create(index(:sales_rooms, [:meeting_type_id]))

    create table(:sales_room_counters) do
      add(:profile_id, references(:profiles, on_delete: :delete_all), null: false)
      add(:booking_page_id, references(:booking_pages, on_delete: :delete_all))
      add(:scope_key, :string, null: false)
      add(:page_views, :integer, null: false, default: 0)
      add(:document_downloads, :integer, null: false, default: 0)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:sales_room_counters, [:scope_key]))
    create(index(:sales_room_counters, [:profile_id]))
  end
end
