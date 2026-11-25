defmodule Tymeslot.SalesRooms.SalesRoomSchema do
  @moduledoc """
  One sales-room document. The row belongs to a profile, optionally to one
  booking page (the profile's own page when that is nil) and optionally to
  one meeting type, which then replaces the page document.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Tymeslot.BookingPages.BookingPageSchema
  alias Tymeslot.MeetingTypes.MeetingTypeSchema
  alias Tymeslot.Profiles.ProfileSchema

  schema "sales_rooms" do
    belongs_to :profile, ProfileSchema
    belongs_to :booking_page, BookingPageSchema
    belongs_to :meeting_type, MeetingTypeSchema
    field :scope_key, :string
    field :document, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:profile_id, :booking_page_id, :meeting_type_id, :document])
    |> validate_required([:profile_id, :document])
    |> put_scope_key()
    |> unique_constraint(:scope_key)
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:booking_page_id)
    |> foreign_key_constraint(:meeting_type_id)
  end

  @doc "Stable identity of a page-level room or an event-type override."
  @spec scope_key(integer(), integer() | nil, integer() | nil) :: String.t()
  def scope_key(profile_id, booking_page_id, meeting_type_id) do
    "#{profile_id}:#{booking_page_id || 0}:#{meeting_type_id || 0}"
  end

  defp put_scope_key(changeset) do
    profile_id = get_field(changeset, :profile_id)

    if is_integer(profile_id) do
      put_change(
        changeset,
        :scope_key,
        scope_key(
          profile_id,
          get_field(changeset, :booking_page_id),
          get_field(changeset, :meeting_type_id)
        )
      )
    else
      changeset
    end
  end
end
