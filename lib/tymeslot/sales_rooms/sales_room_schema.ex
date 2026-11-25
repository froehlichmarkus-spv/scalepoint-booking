defmodule Tymeslot.SalesRooms.SalesRoomSchema do
  @moduledoc """
  One sales-room document. The profile page uses a null booking page and a
  null meeting type. An extra booking page sets `booking_page_id`. A meeting
  type sets `meeting_type_id` and `override`; while override is off the page
  document is what guests see.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Tymeslot.BookingPages.BookingPageSchema
  alias Tymeslot.MeetingTypes.MeetingTypeSchema
  alias Tymeslot.Profiles.ProfileSchema

  schema "sales_rooms" do
    field :scope_key, :string
    field :override, :boolean, default: false
    field :accent, :string
    field :blocks, {:array, :map}, default: []
    field :page_views, :integer, default: 0
    field :download_counts, :map, default: %{}

    belongs_to :profile, ProfileSchema
    belongs_to :booking_page, BookingPageSchema
    belongs_to :meeting_type, MeetingTypeSchema

    timestamps(type: :utc_datetime)
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [
      :profile_id,
      :booking_page_id,
      :meeting_type_id,
      :scope_key,
      :override,
      :accent,
      :blocks
    ])
    |> validate_required([:profile_id, :scope_key, :blocks])
    |> unique_constraint(:scope_key)
    |> foreign_key_constraint(:profile_id)
    |> foreign_key_constraint(:booking_page_id)
    |> foreign_key_constraint(:meeting_type_id)
  end
end
