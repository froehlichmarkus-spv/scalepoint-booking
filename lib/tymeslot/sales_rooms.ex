defmodule Tymeslot.SalesRooms do
  @moduledoc """
  The host-managed sales room on a booking page.

  A page has one document. A meeting type may replace it. Pro (or a
  self-hosted instance with plans switched off) may edit and publish it.
  Free keeps the document and the public page shows the calendar alone.
  """

  alias Tymeslot.BookingPages
  alias Tymeslot.Plans
  alias Tymeslot.SalesRooms.Document
  alias Tymeslot.SalesRooms.Metrics
  alias Tymeslot.SalesRooms.SalesRoomQueries
  alias Tymeslot.SalesRooms.SalesRoomSchema
  alias Tymeslot.SalesRooms.Storage

  @doc "True when this host may publish a sales room."
  @spec allowed?(integer() | nil) :: boolean()
  def allowed?(user_id) when is_integer(user_id) do
    not Plans.enabled?() or
      Plans.feature?(Plans.effective_plan(user_id), :sales_room_allowed)
  end

  def allowed?(_user_id), do: false

  @doc "The saved room for this page or event type, or a blank one."
  @spec fetch(integer(), integer() | nil, integer() | nil) :: {:ok, map()}
  def fetch(profile_id, booking_page_id, meeting_type_id) when is_integer(profile_id) do
    document =
      case SalesRoomQueries.get_room(profile_id, booking_page_id, meeting_type_id) do
        %SalesRoomSchema{document: document} -> document
        nil -> Document.blank()
      end

    Document.normalize(document)
  end

  @doc "Whether an event type has its own room, rather than the page's."
  @spec override?(integer(), integer() | nil, integer()) :: boolean()
  def override?(profile_id, booking_page_id, meeting_type_id)
      when is_integer(profile_id) and is_integer(meeting_type_id) do
    SalesRoomQueries.get_room(profile_id, booking_page_id, meeting_type_id) != nil
  end

  def override?(_profile_id, _booking_page_id, _meeting_type_id), do: false

  @doc "Meeting types the host may attach an override to."
  @spec event_types(integer()) :: [%{id: integer(), name: String.t()}]
  def event_types(user_id) when is_integer(user_id), do: SalesRoomQueries.event_types(user_id)

  @doc """
  Writes `document` when the host may publish and the page and event type
  are theirs. A refused write leaves the stored document as it was.
  """
  @spec save(map(), integer() | nil, integer() | nil, map()) ::
          {:ok, map()} | {:error, term()}
  def save(
        %{id: profile_id, user_id: user_id} = profile,
        booking_page_id,
        meeting_type_id,
        document
      )
      when is_integer(profile_id) do
    with :ok <- ensure_allowed(user_id),
         :ok <- owned_scope?(profile, booking_page_id, meeting_type_id),
         {:ok, normalized} <- Document.normalize(document) do
      write(profile_id, booking_page_id, meeting_type_id, normalized)
    end
  end

  def save(_profile, _booking_page_id, _meeting_type_id, _document),
    do: {:error, :invalid_document}

  @spec toggle(map(), integer() | nil, integer() | nil, String.t(), boolean()) ::
          {:ok, map()} | {:error, term()}
  def toggle(profile, booking_page_id, meeting_type_id, block_id, enabled) do
    with {:ok, document} <- fetch(profile.id, booking_page_id, meeting_type_id),
         {:ok, updated} <- Document.toggle(document, block_id, enabled) do
      save(profile, booking_page_id, meeting_type_id, updated)
    end
  end

  @spec move(map(), integer() | nil, integer() | nil, String.t(), :up | :down) ::
          {:ok, map()} | {:error, term()}
  def move(profile, booking_page_id, meeting_type_id, block_id, direction) do
    with {:ok, document} <- fetch(profile.id, booking_page_id, meeting_type_id),
         {:ok, updated} <- Document.move(document, block_id, direction) do
      save(profile, booking_page_id, meeting_type_id, updated)
    end
  end

  @spec put_block(map(), integer() | nil, integer() | nil, String.t(), map()) ::
          {:ok, map()} | {:error, term()}
  def put_block(profile, booking_page_id, meeting_type_id, block_id, fields) do
    with {:ok, document} <- fetch(profile.id, booking_page_id, meeting_type_id),
         {:ok, updated} <- Document.put_block(document, block_id, fields) do
      save(profile, booking_page_id, meeting_type_id, updated)
    end
  end

  @doc "Drops an event-type override so the page document shows again."
  @spec reset_override(map(), integer() | nil, integer()) :: :ok | {:error, term()}
  def reset_override(
        %{id: profile_id, user_id: user_id} = profile,
        booking_page_id,
        meeting_type_id
      )
      when is_integer(meeting_type_id) do
    with :ok <- ensure_allowed(user_id),
         :ok <- owned_scope?(profile, booking_page_id, meeting_type_id) do
      case SalesRoomQueries.get_room(profile_id, booking_page_id, meeting_type_id) do
        nil ->
          :ok

        room ->
          case SalesRoomQueries.delete_room(room) do
            {:ok, _deleted} -> :ok
            {:error, reason} -> {:error, reason}
          end
      end
    end
  end

  @doc """
  The blocks a visitor of `profile` sees for `meeting_type_id`.

  An event-type row replaces the page. A free plan, or a room with nothing
  ready to show, returns nil and the page stays a calendar.
  """
  @spec for_public(map() | nil, integer() | nil) :: map() | nil
  def for_public(%{id: profile_id, user_id: user_id} = profile, meeting_type_id) do
    if allowed?(user_id) do
      page_id = BookingPages.page_id(profile)

      blocks =
        profile_id
        |> resolve_document(page_id, meeting_type_id)
        |> Document.public_blocks(profile_id)

      if blocks == [] do
        nil
      else
        %{blocks: blocks, profile_id: profile_id, booking_page_id: page_id}
      end
    end
  end

  def for_public(_profile, _meeting_type_id), do: nil

  @doc """
  Records one view when the connected visit is showing a sales room.
  Owner previews are not counted.
  """
  @spec record_public_view(map() | nil, integer() | nil, boolean()) :: :ok
  def record_public_view(_profile, _meeting_type_id, true), do: :ok

  def record_public_view(profile, meeting_type_id, false) do
    case for_public(profile, meeting_type_id) || for_public(profile, nil) do
      %{profile_id: profile_id, booking_page_id: page_id} ->
        Metrics.record_view(profile_id, page_id)

      _hidden ->
        :ok
    end
  end

  @doc """
  A PDF the visitor may download: it is named by a published document of
  this profile. Returns the relative path, the attachment name and the page.
  """
  @spec public_file(integer(), String.t()) ::
          {:ok, String.t(), String.t(), integer() | nil} | :error
  def public_file(profile_id, filename)
      when is_integer(profile_id) and is_binary(filename) do
    with true <- Regex.match?(~r/\A[0-9a-f-]{36}\.pdf\z/, filename),
         %{} = profile <- profile_with_user(profile_id),
         true <- allowed?(profile.user_id) do
      needle = "sales_rooms/#{profile_id}/documents/#{filename}"

      profile_id
      |> SalesRoomQueries.published_documents()
      |> Enum.find_value(:error, fn {page_id, document} ->
        file =
          document
          |> Document.public_blocks(profile_id)
          |> Enum.find_value(fn
            %{"type" => "documents", "files" => files} ->
              Enum.find(files, &(&1["path"] == needle))

            _other ->
              nil
          end)

        if file, do: {:ok, needle, file["name"], page_id}
      end)
    else
      _refused -> :error
    end
  end

  def public_file(_profile_id, _filename), do: :error

  @doc "Stores an upload and returns its relative path."
  @spec store_upload(map(), :image | :video | :document, map()) ::
          {:ok, String.t()} | {:ok, String.t(), non_neg_integer()} | {:error, term()}
  def store_upload(%{id: profile_id, user_id: user_id}, kind, upload) do
    if allowed?(user_id) do
      Storage.store(profile_id, kind, upload)
    else
      {:error, :pro_required}
    end
  end

  @doc "Page views and downloads for the editor."
  @spec stats(integer(), integer() | nil) :: %{
          page_views: non_neg_integer(),
          document_downloads: non_neg_integer()
        }
  def stats(profile_id, booking_page_id), do: Metrics.get(profile_id, booking_page_id)

  defp write(profile_id, booking_page_id, meeting_type_id, document) do
    attrs = %{
      profile_id: profile_id,
      booking_page_id: booking_page_id,
      meeting_type_id: meeting_type_id,
      document: document
    }

    result =
      case SalesRoomQueries.get_room(profile_id, booking_page_id, meeting_type_id) do
        nil -> SalesRoomQueries.insert_room(attrs)
        room -> SalesRoomQueries.update_room(room, attrs)
      end

    case result do
      {:ok, saved} -> {:ok, saved.document}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp resolve_document(profile_id, page_id, meeting_type_id) do
    override =
      if is_integer(meeting_type_id),
        do: SalesRoomQueries.get_room(profile_id, page_id, meeting_type_id)

    case override || SalesRoomQueries.get_room(profile_id, page_id, nil) do
      %SalesRoomSchema{document: document} -> document
      nil -> nil
    end
  end

  defp owned_scope?(profile, booking_page_id, meeting_type_id) do
    cond do
      not owned_page?(profile.id, booking_page_id) -> {:error, :not_found}
      not owned_event?(profile.user_id, meeting_type_id) -> {:error, :not_found}
      true -> :ok
    end
  end

  defp owned_page?(_profile_id, nil), do: true

  defp owned_page?(profile_id, page_id) when is_integer(page_id) do
    SalesRoomQueries.page_owned?(profile_id, page_id)
  end

  defp owned_page?(_profile_id, _page_id), do: false

  defp owned_event?(_user_id, nil), do: true

  defp owned_event?(user_id, meeting_type_id) when is_integer(meeting_type_id) do
    SalesRoomQueries.event_owned?(user_id, meeting_type_id)
  end

  defp owned_event?(_user_id, _meeting_type_id), do: false

  defp profile_with_user(profile_id), do: SalesRoomQueries.profile(profile_id)

  defp ensure_allowed(user_id) do
    if allowed?(user_id), do: :ok, else: {:error, :pro_required}
  end
end
