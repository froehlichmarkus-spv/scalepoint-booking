defmodule Tymeslot.SalesRooms do
  @moduledoc """
  Host-edited sales room for a booking page.

  Free keeps the rows and the files. The public page only renders a room
  while the plan includes `:sales_room_allowed`. Turning plans off (a
  self-hosted install) leaves the room available, like the other features.
  """

  import Ecto.Query, warn: false

  alias Tymeslot.Plans
  alias Tymeslot.Repo
  alias Tymeslot.SalesRooms.Blocks
  alias Tymeslot.SalesRooms.SalesRoomSchema
  alias Tymeslot.SalesRooms.Storage

  @accent ~r/\A#[0-9A-Fa-f]{6}\z/

  def allowed?(user_id) when is_integer(user_id) do
    not Plans.enabled?() or Plans.feature?(Plans.effective_plan(user_id), :sales_room_allowed)
  end

  def allowed?(_), do: false

  def blank_blocks, do: Blocks.blank()

  @doc "The document the editor shows. It is created on the first save."
  def get(profile_id, booking_page_id, meeting_type_id) do
    Repo.get_by(SalesRoomSchema,
      scope_key: scope_key(profile_id, booking_page_id, meeting_type_id)
    )
  end

  def scope_key(profile_id, booking_page_id, meeting_type_id) do
    "p#{profile_id}-b#{booking_page_id || 0}-m#{meeting_type_id || 0}"
  end

  @doc "Writes blocks for a host whose plan includes the sales room."
  def save(user_id, profile_id, booking_page_id, meeting_type_id, attrs)
      when is_integer(user_id) do
    if allowed?(user_id) do
      write(profile_id, booking_page_id, meeting_type_id, attrs)
    else
      {:error, :upgrade_required}
    end
  end

  def save(_, _, _, _, _), do: {:error, :upgrade_required}

  @doc "Adds one uploaded file to a block list. The previous path is deleted when replaced."
  def attach(user_id, profile_id, booking_page_id, meeting_type_id, block_id, kind, source, name) do
    with true <- allowed?(user_id),
         {:ok, stored} <- store(kind, profile_id, source),
         room <- ensure(profile_id, booking_page_id, meeting_type_id),
         {:ok, blocks, old} <- add_asset(room.blocks, block_id, kind, stored, name),
         {:ok, saved} <- write(profile_id, booking_page_id, meeting_type_id, %{blocks: blocks}) do
      if old, do: Storage.delete(old)
      {:ok, saved}
    else
      false -> {:error, :upgrade_required}
      {:error, reason} -> {:error, reason}
    end
  end

  def detach(user_id, profile_id, booking_page_id, meeting_type_id, block_id, asset_id) do
    with true <- allowed?(user_id),
         %SalesRoomSchema{} = room <- get(profile_id, booking_page_id, meeting_type_id),
         {:ok, blocks, path} <- remove_asset(room.blocks, block_id, asset_id),
         {:ok, saved} <- write(profile_id, booking_page_id, meeting_type_id, %{blocks: blocks}) do
      if path, do: Storage.delete(path)
      {:ok, saved}
    else
      false -> {:error, :upgrade_required}
      nil -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Accent for the page a guest is looking at, or nil."
  def accent_for(%{id: profile_id, user_id: user_id} = profile) when is_integer(profile_id) do
    if allowed?(user_id) do
      page_id = booking_page_id(profile)

      case get(profile_id, page_id, nil) do
        %{accent: accent} -> accent_hex(accent)
        _ -> nil
      end
    end
  end

  def accent_for(_), do: nil

  @doc "Accent for the host's own booking page, when the plan includes the sales room."
  def accent_for_user(user_id) when is_integer(user_id) do
    case Tymeslot.Repo.get_by(Tymeslot.Profiles.ProfileSchema, user_id: user_id) do
      nil -> nil
      profile -> accent_for(profile)
    end
  end

  def accent_for_user(_), do: nil

  @doc "The room a guest may see, or nil when the plan hides it."
  def public_room(%{id: profile_id, user_id: user_id} = profile, meeting_type) do
    if allowed?(user_id) do
      page_id = booking_page_id(profile)
      type_id = meeting_type_id(meeting_type)
      page = get(profile_id, page_id, nil)
      override = if type_id, do: get(profile_id, page_id, type_id)

      chosen =
        cond do
          override && override.override && Blocks.presentable(override.blocks) != [] -> override
          page && Blocks.presentable(page.blocks) != [] -> page
          true -> nil
        end

      chosen && %{chosen | blocks: Blocks.presentable(chosen.blocks)}
    end
  end

  def public_room(_, _), do: nil

  def record_view(%{id: id}) when is_integer(id) do
    Repo.update_all(from(r in SalesRoomSchema, where: r.id == ^id), inc: [page_views: 1])
    :ok
  end

  def record_view(_), do: :ok

  def record_download(room_id, file_id) when is_integer(room_id) and is_binary(file_id) do
    if safe_id?(file_id) do
      Repo.query!(
        """
        UPDATE sales_rooms
        SET download_counts = jsonb_set(
          COALESCE(download_counts, '{}'::jsonb),
          ARRAY[$2]::text[],
          to_jsonb(COALESCE((download_counts->>$2)::int, 0) + 1),
          true
        )
        WHERE id = $1
        """,
        [room_id, file_id]
      )

      :ok
    else
      :error
    end
  end

  def record_download(_, _), do: :error

  @doc "A brochure a guest may download, after the plan check."
  def public_file(room_id, file_id) when is_binary(room_id) or is_integer(room_id) do
    with {id, ""} <- Integer.parse(to_string(room_id)),
         %SalesRoomSchema{} = room <- Repo.get(SalesRoomSchema, id),
         %{user_id: user_id} <- Repo.get(Tymeslot.Profiles.ProfileSchema, room.profile_id),
         true <- allowed?(user_id),
         file when not is_nil(file) <- find_file(room, file_id),
         {:ok, absolute} <- Storage.resolve(file["path"]) do
      {:ok, room, file, absolute}
    else
      _ -> :error
    end
  end

  def editor_document(nil),
    do: %{
      blocks: Blocks.blank(),
      accent: nil,
      page_views: 0,
      download_counts: %{},
      override: false
    }

  def editor_document(%SalesRoomSchema{} = room) do
    %{
      blocks: Blocks.normalize(room.blocks),
      accent: room.accent,
      page_views: room.page_views,
      download_counts: room.download_counts || %{},
      override: room.override
    }
  end

  defp write(profile_id, booking_page_id, meeting_type_id, attrs) do
    blocks = attrs[:blocks] || attrs["blocks"]

    with {:ok, blocks} <- if(blocks, do: Blocks.validate(blocks), else: {:ok, nil}) do
      room = ensure(profile_id, booking_page_id, meeting_type_id)

      changes =
        %{}
        |> maybe(:blocks, blocks || :skip)
        |> maybe(:accent, accent_change(attrs))
        |> maybe(:override, override_change(attrs, meeting_type_id))

      room
      |> SalesRoomSchema.changeset(changes)
      |> Repo.update()
    end
  end

  defp ensure(profile_id, booking_page_id, meeting_type_id) do
    key = scope_key(profile_id, booking_page_id, meeting_type_id)

    case Repo.get_by(SalesRoomSchema, scope_key: key) do
      %SalesRoomSchema{} = room ->
        room

      nil ->
        %SalesRoomSchema{}
        |> SalesRoomSchema.changeset(%{
          profile_id: profile_id,
          booking_page_id: booking_page_id,
          meeting_type_id: meeting_type_id,
          scope_key: key,
          blocks: Blocks.blank(),
          override: false
        })
        |> Repo.insert!()
    end
  end

  defp store(:image, profile_id, source), do: Storage.store_image(profile_id, source)
  defp store(:video, profile_id, source), do: Storage.store_video(profile_id, source)
  defp store(:pdf, profile_id, source), do: Storage.store_pdf(profile_id, source)
  defp store(_, _, _), do: {:error, :invalid_upload}

  defp add_asset(blocks, block_id, kind, path, name) do
    blocks = Blocks.normalize(blocks)
    block = Blocks.find(blocks, block_id)

    cond do
      is_nil(block) or not accepts?(block["type"], kind) ->
        Storage.delete(path)
        {:error, :invalid_upload}

      true ->
        case insert_asset(block, kind, path, name) do
          :full ->
            Storage.delete(path)
            {:error, :too_many}

          {content, old} ->
            {:ok, Blocks.put_content(blocks, block_id, content), old}
        end
    end
  end

  defp accepts?("hero", :image), do: true
  defp accepts?("gallery", :image), do: true
  defp accepts?("logos", :image), do: true
  defp accepts?("video", :video), do: true
  defp accepts?("brochures", :pdf), do: true
  defp accepts?(_, _), do: false

  defp insert_asset(%{"type" => "hero", "content" => content}, :image, path, _name) do
    {Map.merge(content, %{"logo_path" => path, "logo_alt" => content["logo_alt"] || ""}),
     content["logo_path"]}
  end

  defp insert_asset(%{"type" => "video", "content" => content}, :video, path, _name) do
    {Map.put(content, "mp4_path", path), content["mp4_path"]}
  end

  defp insert_asset(%{"type" => type, "content" => content}, :image, path, name) do
    key = if type == "gallery", do: "images", else: "items"
    max = if type == "gallery", do: Blocks.gallery_max(), else: 12
    current = List.wrap(content[key])

    if length(current) >= max do
      :full
    else
      item = %{"id" => random_id(), "path" => path, "alt" => "", "name" => name || ""}
      {Map.put(content, key, current ++ [item]), nil}
    end
  end

  defp insert_asset(%{"type" => "brochures", "content" => content}, :pdf, path, name) do
    current = List.wrap(content["files"])

    if length(current) >= Blocks.brochures_max() do
      :full
    else
      item = %{
        "id" => random_id(),
        "path" => path,
        "title" => name || "PDF",
        "filename" => name || "document.pdf",
        "bytes" => 0
      }

      {Map.put(content, "files", current ++ [item]), nil}
    end
  end

  defp remove_asset(blocks, block_id, asset_id) do
    blocks = Blocks.normalize(blocks)

    case Blocks.find(blocks, block_id) do
      %{"type" => "hero", "content" => content} ->
        if content["logo_path"] != nil and asset_id in ["logo", nil] do
          {:ok, Blocks.put_content(blocks, block_id, %{"logo_path" => nil}), content["logo_path"]}
        else
          drop_listed_block(blocks, block_id, content, asset_id)
        end

      %{"type" => "video", "content" => content} when asset_id == "mp4" ->
        {:ok, Blocks.put_content(blocks, block_id, %{"mp4_path" => nil}), content["mp4_path"]}

      %{"content" => content} ->
        drop_listed_block(blocks, block_id, content, asset_id)

      _ ->
        {:error, :not_found}
    end
  end

  defp drop_listed_block(blocks, block_id, content, asset_id) do
    {next, path} = drop_listed(content, asset_id)
    {:ok, Blocks.put_content(blocks, block_id, next), path}
  end

  defp drop_listed(content, asset_id) do
    Enum.reduce(["images", "items", "files"], {content, nil}, fn key, {acc, found} ->
      list = List.wrap(acc[key])
      {kept, removed} = Enum.split_with(list, &(&1["id"] != asset_id))
      path = found || (removed != [] && hd(removed)["path"])
      {Map.put(acc, key, kept), path}
    end)
  end

  defp find_file(room, file_id) do
    room.blocks
    |> Blocks.normalize()
    |> Enum.find(&(&1["type"] == "brochures"))
    |> case do
      nil ->
        nil

      block ->
        Enum.find(block["content"]["files"], &(&1["id"] == file_id and is_binary(&1["path"])))
    end
  end

  defp booking_page_id(%{booking_page: %{id: id}}) when is_integer(id), do: id
  defp booking_page_id(_), do: nil

  defp meeting_type_id(%{id: id}) when is_integer(id), do: id
  defp meeting_type_id(_), do: nil

  defp accent_change(attrs) do
    if Map.has_key?(attrs, :accent) or Map.has_key?(attrs, "accent") do
      accent_hex(attrs[:accent] || attrs["accent"])
    else
      :skip
    end
  end

  defp override_change(attrs, meeting_type_id) do
    cond do
      is_nil(meeting_type_id) -> false
      Map.has_key?(attrs, :override) -> attrs[:override] == true
      Map.has_key?(attrs, "override") -> attrs["override"] == true
      true -> :skip
    end
  end

  defp maybe(map, _key, :skip), do: map
  defp maybe(map, key, value), do: Map.put(map, key, value)

  defp accent_hex(nil), do: nil
  defp accent_hex(""), do: nil

  defp accent_hex(hex) when is_binary(hex) do
    hex = String.trim(hex)
    if Regex.match?(@accent, hex), do: String.downcase(hex)
  end

  defp accent_hex(_), do: nil

  defp safe_id?(id), do: Regex.match?(~r/\A[A-Za-z0-9_-]{1,40}\z/, id)

  defp random_id, do: 8 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
