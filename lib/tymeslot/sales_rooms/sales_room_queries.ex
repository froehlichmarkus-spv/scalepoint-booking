defmodule Tymeslot.SalesRooms.SalesRoomQueries do
  @moduledoc """
  Reads and writes sales-room rows and their counters.
  """

  import Ecto.Query, warn: false

  alias Tymeslot.BookingPages.BookingPageSchema
  alias Tymeslot.MeetingTypes.MeetingTypeSchema
  alias Tymeslot.Profiles.ProfileSchema
  alias Tymeslot.Repo
  alias Tymeslot.SalesRooms.CounterSchema
  alias Tymeslot.SalesRooms.SalesRoomSchema

  @spec get_room(integer(), integer() | nil, integer() | nil) :: SalesRoomSchema.t() | nil
  def get_room(profile_id, booking_page_id, meeting_type_id) do
    key = SalesRoomSchema.scope_key(profile_id, booking_page_id, meeting_type_id)
    Repo.get_by(SalesRoomSchema, scope_key: key)
  end

  @spec insert_room(map()) :: {:ok, SalesRoomSchema.t()} | {:error, Ecto.Changeset.t()}
  def insert_room(attrs) do
    %SalesRoomSchema{}
    |> SalesRoomSchema.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_room(SalesRoomSchema.t(), map()) ::
          {:ok, SalesRoomSchema.t()} | {:error, Ecto.Changeset.t()}
  def update_room(room, attrs) do
    room
    |> SalesRoomSchema.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_room(SalesRoomSchema.t()) ::
          {:ok, SalesRoomSchema.t()} | {:error, Ecto.Changeset.t()}
  def delete_room(room), do: Repo.delete(room)

  @spec event_types(integer()) :: [%{id: integer(), name: String.t()}]
  def event_types(user_id) do
    Repo.all(
      from mt in MeetingTypeSchema,
        where: mt.user_id == ^user_id,
        order_by: [asc: mt.name],
        select: %{id: mt.id, name: mt.name}
    )
  end

  @spec page_owned?(integer(), integer()) :: boolean()
  def page_owned?(profile_id, page_id) do
    Repo.exists?(
      from page in BookingPageSchema,
        where: page.id == ^page_id and page.profile_id == ^profile_id
    )
  end

  @spec event_owned?(integer(), integer()) :: boolean()
  def event_owned?(user_id, meeting_type_id) do
    Repo.exists?(
      from mt in MeetingTypeSchema,
        where: mt.id == ^meeting_type_id and mt.user_id == ^user_id
    )
  end

  @spec published_documents(integer()) :: [{integer() | nil, map()}]
  def published_documents(profile_id) do
    SalesRoomSchema
    |> where([room], room.profile_id == ^profile_id)
    |> Repo.all()
    |> Enum.map(&{&1.booking_page_id, &1.document})
  end

  @spec profile(integer()) :: ProfileSchema.t() | nil
  def profile(profile_id) do
    Repo.get(ProfileSchema, profile_id)
  end

  @spec counter(integer(), integer() | nil) :: CounterSchema.t() | nil
  def counter(profile_id, booking_page_id) do
    key = CounterSchema.scope_key(profile_id, booking_page_id)
    Repo.get_by(CounterSchema, scope_key: key)
  end

  @spec bump_counter(integer(), integer() | nil, :page_views | :document_downloads) :: :ok
  def bump_counter(profile_id, booking_page_id, field) do
    now = DateTime.utc_now(:second)
    key = CounterSchema.scope_key(profile_id, booking_page_id)

    attrs = %{
      profile_id: profile_id,
      booking_page_id: booking_page_id,
      scope_key: key,
      page_views: if(field == :page_views, do: 1, else: 0),
      document_downloads: if(field == :document_downloads, do: 1, else: 0),
      inserted_at: now,
      updated_at: now
    }

    Repo.insert_all(CounterSchema, [attrs],
      on_conflict: [inc: [{field, 1}], set: [updated_at: now]],
      conflict_target: [:scope_key]
    )

    :ok
  end
end
