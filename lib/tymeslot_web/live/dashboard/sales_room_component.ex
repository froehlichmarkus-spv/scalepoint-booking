defmodule TymeslotWeb.Dashboard.SalesRoomComponent do
  @moduledoc """
  The host's editor for a booking page's sales room: switch blocks on,
  reorder them, edit them, upload files and watch the visitor's view.
  """

  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.BookingPages
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Document
  alias Tymeslot.SalesRooms.Draft
  alias Tymeslot.SalesRooms.Storage
  alias TymeslotWeb.Dashboard.SalesRoomFields
  alias TymeslotWeb.SalesRooms.Public

  @uploads [
    hero_image: :image,
    gallery_image: :image,
    video_file: :video,
    document_file: :document,
    quote_photo: :image,
    logo_image: :image
  ]

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:selected, fn -> "hero" end)
      |> assign_new(:form_error, fn -> nil end)
      |> assign_new(:photo_index, fn -> 0 end)
      |> allow_uploads()
      |> load_scope()
      |> consume_pending()

    {:ok, socket}
  end

  @impl Phoenix.LiveComponent
  def render(assigns) do
    assigns =
      assigns
      |> assign(:block, Draft.block(assigns.draft, assigns.selected))
      |> assign(:preview, Document.public_blocks(assigns.draft, assigns.profile.id))

    ~H"""
    <div id={@id}>
      <.dashboard_page icon="hero-sparkles" title={dgettext("dashboard_booking_pages", "Sales room")}>
        <p class="max-w-2xl text-token-sm text-tymeslot-600">
          {dgettext(
            "dashboard_booking_pages",
            "Tell the story beside the calendar. Visitors on a phone get a button that leads to the times."
          )}
        </p>

        <div
          :if={!@allowed}
          class="rounded-token border border-tymeslot-200 bg-white p-4"
          data-testid="sales-room-upgrade"
        >
          <p class="font-semibold text-tymeslot-800">
            {dgettext("dashboard_booking_pages", "Sales room is part of Pro")}
          </p>
          <p class="mt-1 text-token-sm text-tymeslot-600">
            {dgettext(
              "dashboard_booking_pages",
              "Free keeps the calendar and the Powered by BookDesk24 badge. Your text stays here and comes back if you upgrade. Nothing is deleted."
            )}
          </p>
          <.link patch={~p"/dashboard/plan"} class="mt-3 inline-flex text-token-sm font-semibold">
            {dgettext("dashboard_booking_pages", "View plans")}
          </.link>
        </div>

        <div class="flex flex-wrap gap-3">
          <form
            id="sales-room-scope"
            phx-change="select_scope"
            phx-target={@myself}
            class="flex flex-wrap gap-3"
            novalidate
          >
            <.select
              id="sales-room-page"
              name="page"
              label={dgettext("dashboard_booking_pages", "Booking page")}
              value={@page_id || ""}
              options={[
                {dgettext("dashboard_booking_pages", "Main page"), ""}
                | Enum.map(@pages, &{&1.name, &1.id})
              ]}
            />
            <.select
              id="sales-room-event"
              name="event"
              label={dgettext("dashboard_booking_pages", "Event type")}
              value={@event_id || ""}
              options={[
                {dgettext("dashboard_booking_pages", "Whole page"), ""}
                | Enum.map(@events, &{&1.name, &1.id})
              ]}
            />
          </form>
          <button
            :if={@event_id && @override?}
            type="button"
            class="text-token-sm font-semibold"
            phx-click="reset_override"
            phx-target={@myself}
            data-testid="sales-room-reset"
          >
            {dgettext("dashboard_booking_pages", "Use the page again")}
          </button>
        </div>

        <p :if={@inherited} class="text-token-sm text-tymeslot-600" data-testid="sales-room-inherited">
          {dgettext(
            "dashboard_booking_pages",
            "This event uses the page. Saving here keeps a version just for it."
          )}
        </p>

        <p class="text-token-xs text-tymeslot-500" data-testid="sales-room-stats">
          {dgettext("dashboard_booking_pages", "Views %{views}, downloads %{downloads}",
            views: @stats.page_views,
            downloads: @stats.document_downloads
          )}
        </p>

        <div class="grid gap-6 lg:grid-cols-[18rem_minmax(0,1fr)]">
          <ol class="space-y-2" data-testid="sales-room-blocks">
            <li
              :for={{block, index} <- Enum.with_index(@draft["blocks"])}
              class="flex items-center gap-2"
            >
              <button
                type="button"
                class={[
                  "min-w-0 flex-1 rounded-token border px-3 py-2 text-left text-token-sm",
                  @selected == block["id"] && "border-tymeslot-400 bg-white font-semibold"
                ]}
                phx-click="select_block"
                phx-value-id={block["id"]}
                phx-target={@myself}
              >
                {SalesRoomFields.label(block["id"])}
                <span class="ml-2 text-token-xs text-tymeslot-500">
                  {if block["enabled"],
                    do: dgettext("dashboard_booking_pages", "On"),
                    else: dgettext("dashboard_booking_pages", "Off")}
                </span>
              </button>
              <button
                type="button"
                class="rounded-token border px-2 py-2 text-token-xs"
                phx-click="move_block"
                phx-value-id={block["id"]}
                phx-value-direction="up"
                phx-target={@myself}
                disabled={!@allowed || index == 0}
                aria-label={dgettext("dashboard_booking_pages", "Move up")}
                data-testid={"sales-room-up-#{block["id"]}"}
              >
                ↑
              </button>
              <button
                type="button"
                class="rounded-token border px-2 py-2 text-token-xs"
                phx-click="move_block"
                phx-value-id={block["id"]}
                phx-value-direction="down"
                phx-target={@myself}
                disabled={!@allowed || index == length(@draft["blocks"]) - 1}
                aria-label={dgettext("dashboard_booking_pages", "Move down")}
                data-testid={"sales-room-down-#{block["id"]}"}
              >
                ↓
              </button>
            </li>
          </ol>

          <div class="space-y-6">
            <.card padding={:lg} class="space-y-4" data-testid="sales-room-editor">
              <div class="flex items-center justify-between gap-3">
                <h2 class="font-semibold">{SalesRoomFields.label(@selected)}</h2>
                <button
                  type="button"
                  class="rounded-token border px-3 py-1.5 text-token-sm"
                  phx-click="toggle_block"
                  phx-value-id={@selected}
                  phx-target={@myself}
                  disabled={!@allowed}
                  data-testid="sales-room-toggle"
                >
                  {if @block["enabled"],
                    do: dgettext("dashboard_booking_pages", "Hide block"),
                    else: dgettext("dashboard_booking_pages", "Show block")}
                </button>
              </div>

              <p :if={@form_error} class="text-token-sm text-red-700" data-testid="sales-room-error">
                {SalesRoomFields.error_text(@form_error)}
              </p>

              <form
                id="sales-room-form"
                phx-change="draft"
                phx-submit="save"
                phx-target={@myself}
                class="space-y-4"
                novalidate
              >
                <SalesRoomFields.fields
                  block={@block}
                  uploads={@uploads}
                  myself={@myself}
                  photo_index={@photo_index}
                  allowed={@allowed}
                />
                <button
                  type="submit"
                  class="action-button--primary rounded-token px-4 py-2 text-token-sm font-semibold"
                  disabled={!@allowed}
                  data-testid="sales-room-save"
                >
                  {dgettext("dashboard_booking_pages", "Save block")}
                </button>
              </form>
            </.card>

            <div data-testid="sales-room-preview">
              <h2 class="mb-3 text-token-sm font-semibold text-tymeslot-600">
                {dgettext("dashboard_booking_pages", "Preview")}
              </h2>
              <div class="folio-page rounded-token bg-tymeslot-50 p-4">
                <Public.story
                  :if={@preview != []}
                  blocks={@preview}
                  profile={@profile}
                  locale={@locale || "en"}
                  preview={true}
                />
                <p :if={@preview == []} class="text-token-sm text-tymeslot-600">
                  {dgettext(
                    "dashboard_booking_pages",
                    "Nothing is ready to show yet. The page stays a calendar until a block is complete."
                  )}
                </p>
              </div>
            </div>
          </div>
        </div>
      </.dashboard_page>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("select_scope", params, socket) do
    query =
      %{}
      |> maybe_query("page", params["page"])
      |> maybe_query("event", params["event"])

    {:noreply, push_patch(socket, to: ~p"/dashboard/sales-room?#{query}")}
  end

  def handle_event("select_block", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected: id, form_error: nil)}
  end

  def handle_event("draft", params, socket) do
    draft = Draft.apply_form(socket.assigns.draft, socket.assigns.selected, params)
    {:noreply, assign(socket, :draft, draft)}
  end

  def handle_event("save", params, socket) do
    id = socket.assigns.selected
    draft = Draft.apply_form(socket.assigns.draft, id, params)

    result =
      with {:ok, updated} <- Document.put_block(draft, id, Draft.block(draft, id)) do
        SalesRooms.save(
          socket.assigns.profile,
          socket.assigns.page_id,
          socket.assigns.event_id,
          updated
        )
      end

    {:noreply, saved(socket, result, draft)}
  end

  def handle_event("toggle_block", %{"id" => id}, socket) do
    enabled = not Draft.block(socket.assigns.draft, id)["enabled"]
    {:noreply, persist(socket, Document.toggle(socket.assigns.draft, id, enabled))}
  end

  def handle_event("move_block", %{"id" => id, "direction" => direction}, socket)
      when direction in ["up", "down"] do
    {:noreply,
     persist(socket, Document.move(socket.assigns.draft, id, String.to_existing_atom(direction)))}
  end

  def handle_event("add_item", _params, socket) do
    {:noreply,
     persist(socket, {:ok, Draft.add_item(socket.assigns.draft, socket.assigns.selected)})}
  end

  def handle_event("remove_item", %{"index" => index}, socket) do
    case Integer.parse(index) do
      {parsed, ""} ->
        {:noreply,
         persist(
           socket,
           {:ok, Draft.remove_item(socket.assigns.draft, socket.assigns.selected, parsed)}
         )}

      _invalid ->
        {:noreply, socket}
    end
  end

  def handle_event("aim_photo", %{"index" => index}, socket) do
    case Integer.parse(index) do
      {parsed, ""} -> {:noreply, assign(socket, :photo_index, parsed)}
      _invalid -> {:noreply, socket}
    end
  end

  def handle_event("reset_override", _params, socket) do
    _result =
      SalesRooms.reset_override(
        socket.assigns.profile,
        socket.assigns.page_id,
        socket.assigns.event_id
      )

    {:noreply, load_scope(assign(socket, :loaded_key, nil))}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp allow_uploads(socket) do
    Enum.reduce(@uploads, socket, fn {name, kind}, acc ->
      if declared?(acc, name) do
        acc
      else
        allow_upload(acc, name,
          accept: Storage.accept(kind),
          max_entries: 1,
          max_file_size: Storage.max_bytes(kind),
          auto_upload: true,
          progress: &progress(&1, &2, &3, name)
        )
      end
    end)
  end

  defp declared?(socket, name), do: Map.has_key?(socket.assigns[:uploads] || %{}, name)

  defp progress(_config, entry, socket, name) do
    if entry.done? do
      send_update(self(), __MODULE__,
        id: socket.assigns[:id] || "sales_room",
        consume_upload: name
      )
    end

    {:noreply, socket}
  end

  defp load_scope(socket) do
    profile = socket.assigns.profile
    pages = BookingPages.list(profile.id)
    events = SalesRooms.event_types(profile.user_id)
    page_id = allowed_id(socket.assigns.params["page"], Enum.map(pages, & &1.id))
    event_id = allowed_id(socket.assigns.params["event"], Enum.map(events, & &1.id))
    key = "#{page_id}:#{event_id}"

    if socket.assigns[:loaded_key] == key do
      socket
    else
      override? = is_integer(event_id) and SalesRooms.override?(profile.id, page_id, event_id)
      source_event = if override?, do: event_id, else: nil
      {:ok, document} = SalesRooms.fetch(profile.id, page_id, source_event)

      assign(socket,
        pages: pages,
        events: events,
        page_id: page_id,
        event_id: event_id,
        override?: override?,
        inherited: is_integer(event_id) and not override?,
        document: document,
        draft: document,
        loaded_key: key,
        allowed: SalesRooms.allowed?(profile.user_id),
        stats: SalesRooms.stats(profile.id, page_id),
        locale: socket.assigns[:locale] || profile_locale(profile)
      )
    end
  end

  defp consume_pending(socket) do
    name = socket.assigns[:consume_upload]

    if name in Keyword.keys(@uploads) do
      socket
      |> assign(:consume_upload, nil)
      |> store_finished(name)
    else
      socket
    end
  end

  defp store_finished(socket, name) do
    kind = Keyword.fetch!(@uploads, name)

    if socket.assigns.allowed do
      consumed =
        consume_uploaded_entries(socket, name, fn %{path: path}, entry ->
          upload = %{path: path, filename: entry.client_name}

          case SalesRooms.store_upload(socket.assigns.profile, kind, upload) do
            {:ok, stored} -> {:ok, {stored, nil, entry.client_name}}
            {:ok, stored, bytes} -> {:ok, {stored, bytes, entry.client_name}}
            {:error, reason} -> {:ok, {:error, reason}}
          end
        end)

      case consumed do
        [{stored, bytes, client_name} | _rest] ->
          draft = attach(socket.assigns.draft, name, stored, bytes, client_name, socket.assigns)
          persist(%{socket | assigns: Map.put(socket.assigns, :draft, draft)}, {:ok, draft})

        [{:error, reason} | _rest] ->
          assign(socket, form_error: reason)

        _empty ->
          socket
      end
    else
      socket
    end
  end

  defp attach(document, :hero_image, path, _bytes, _name, _socket) do
    Draft.put_in_block(document, "hero", fn block -> %{block | "image_path" => path} end)
  end

  defp attach(document, :gallery_image, path, _bytes, _name, _socket) do
    Draft.put_in_block(document, "gallery", fn block ->
      %{block | "images" => block["images"] ++ [%{"path" => path, "alt" => ""}]}
    end)
  end

  defp attach(document, :video_file, path, _bytes, _name, _socket) do
    Draft.put_in_block(document, "video", fn block -> %{block | "file_path" => path} end)
  end

  defp attach(document, :document_file, path, bytes, client_name, _socket) do
    Draft.put_in_block(document, "documents", fn block ->
      file = %{
        "path" => path,
        "name" => Document.safe_filename(client_name),
        "bytes" => bytes || 0
      }

      %{block | "files" => block["files"] ++ [file]}
    end)
  end

  defp attach(document, :quote_photo, path, _bytes, _name, socket) do
    index = socket.assigns.photo_index

    Draft.put_in_block(document, "testimonials", fn block ->
      if is_integer(index) and index >= 0 and index < length(block["items"]) do
        items = List.update_at(block["items"], index, &Map.put(&1, "photo_path", path))
        %{block | "items" => items}
      else
        block
      end
    end)
  end

  defp attach(document, :logo_image, path, _bytes, _name, _socket) do
    Draft.put_in_block(document, "logos", fn block ->
      %{block | "items" => block["items"] ++ [%{"path" => path, "alt" => ""}]}
    end)
  end

  defp persist(socket, {:ok, document}) do
    if socket.assigns.allowed do
      result =
        SalesRooms.save(
          socket.assigns.profile,
          socket.assigns.page_id,
          socket.assigns.event_id,
          document
        )

      saved(socket, result, document)
    else
      assign(socket, form_error: :pro_required)
    end
  end

  defp persist(socket, {:error, reason}), do: assign(socket, form_error: reason)

  defp saved(socket, {:ok, document}, _draft) do
    assign(socket,
      document: document,
      draft: document,
      form_error: nil,
      override?: not is_nil(socket.assigns.event_id),
      inherited: false
    )
  end

  defp saved(socket, {:error, reason}, draft),
    do: assign(socket, draft: draft, form_error: reason)

  defp allowed_id(nil, _ids), do: nil
  defp allowed_id("", _ids), do: nil

  defp allowed_id(raw, ids) do
    case Integer.parse(to_string(raw)) do
      {id, ""} -> if id in ids, do: id
      _invalid -> nil
    end
  end

  defp maybe_query(query, _key, value) when value in [nil, ""], do: query
  defp maybe_query(query, key, value), do: Map.put(query, key, value)

  defp profile_locale(%{content_locale: locale}) when is_binary(locale), do: locale
  defp profile_locale(_profile), do: "en"
end
