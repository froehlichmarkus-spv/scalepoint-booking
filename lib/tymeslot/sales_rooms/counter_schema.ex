defmodule Tymeslot.SalesRooms.CounterSchema do
  @moduledoc """
  Page views and document downloads for one booking page.

  Counts only. No visitor address, cookie or third-party identifier is stored.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Tymeslot.BookingPages.BookingPageSchema
  alias Tymeslot.Profiles.ProfileSchema

  schema "sales_room_counters" do
    belongs_to :profile, ProfileSchema
    belongs_to :booking_page, BookingPageSchema
    field :scope_key, :string
    field :page_views, :integer, default: 0
    field :document_downloads, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(counter, attrs) do
    counter
    |> cast(attrs, [:profile_id, :booking_page_id, :page_views, :document_downloads])
    |> validate_required([:profile_id])
    |> validate_number(:page_views, greater_than_or_equal_to: 0)
    |> validate_number(:document_downloads, greater_than_or_equal_to: 0)
    |> put_scope_key()
    |> unique_constraint(:scope_key)
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:booking_page_id)
  end

  @spec scope_key(integer(), integer() | nil) :: String.t()
  def scope_key(profile_id, booking_page_id), do: "#{profile_id}:#{booking_page_id || 0}"

  defp put_scope_key(changeset) do
    profile_id = get_field(changeset, :profile_id)

    if is_integer(profile_id) do
      put_change(
        changeset,
        :scope_key,
        scope_key(profile_id, get_field(changeset, :booking_page_id))
      )
    else
      changeset
    end
  end
end
