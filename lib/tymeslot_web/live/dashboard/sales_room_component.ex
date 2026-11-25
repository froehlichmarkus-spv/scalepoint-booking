defmodule TymeslotWeb.Dashboard.SalesRoomComponent do
  @moduledoc """
  Self-service editor for the sales room. Free hosts see every block and an
  upgrade note. Saving is refused, and a later downgrade does not delete the
  document.
  """

  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.BookingPages.Addresses
  alias Tymeslot.BookingPages.BookingPageQueries
  alias Tymeslot.MeetingTypes.MeetingTypeQueries
  alias Tymeslot.SalesRooms
  alias Tymeslot.SalesRooms.Blocks
  alias TymeslotWeb.SalesRooms.Story

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if socket.assigns[:booted] do
        socket
      else
        socket
        |> boot()
        |> assign(:booted, true)
      end

    {:ok, allow_asset_upload(socket)}
  end

  @impl true
  def handle_event("page", %{"booking_page_id" => id}, socket) do
    page_id = blank_id(id)
    {:noreply, socket |> assign(booking_page_id: page_id, meeting_type_id: nil) |> reload()}
  end

  def handle_event("scope", %{"meeting_type_id" => id}, socket) do
    {:noreply, socket |> assign(:meeting_type_id, blank_id(id)) |> reload()}
  end

  def handle_event("select", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected, id)}
  end

  def handle_event("toggle", %{"id" => id}, socket) do
    block = Blocks.find(socket.assigns.blocks, id)
    blocks = Blocks.put_enabled(socket.assigns.blocks, id, not block["enabled"])
    persist(socket, %{blocks: blocks})
  end

  def handle_event("move", %{"id" => id, "dir" => dir}, socket) when dir in ["up", "down"] do
    direction = if dir == "up", do: :up, else: :down
    persist(socket, %{blocks: Blocks.move(socket.assigns.blocks, id, direction)})
  end

  def handle_event("override", %{"override" => value}, socket) do
    enabled = value == "true" or (is_list(value) and "true" in value)

    blocks =
      if enabled and socket.assigns.meeting_type_id do
        page = SalesRooms.get(socket.assigns.profile.id, socket.assigns.booking_page_id, nil)
        (page && Blocks.normalize(page.blocks)) || socket.assigns.blocks
      else
        socket.assigns.blocks
      end

    persist(socket, %{blocks: blocks, override: enabled})
  end

  def handle_event("accent", %{"accent" => accent}, socket) do
    persist(socket, %{accent: accent})
  end

  def handle_event("save_block", %{"block_id" => id} = params, socket) do
    content = content_from(Blocks.find(socket.assigns.blocks, id), params)
    persist(socket, %{blocks: Blocks.put_content(socket.assigns.blocks, id, content)})
  end

  def handle_event("add_item", %{"id" => id}, socket) do
    block = Blocks.find(socket.assigns.blocks, id)
    items = List.wrap(block["content"]["items"]) ++ [blank_item(block["type"])]
    content = Map.put(block["content"], "items", items)
    persist(socket, %{blocks: Blocks.put_content(socket.assigns.blocks, id, content)})
  end

  def handle_event("remove_item", %{"id" => id, "item" => item_id}, socket) do
    block = Blocks.find(socket.assigns.blocks, id)
    items = Enum.reject(block["content"]["items"] || [], &(&1["id"] == item_id))
    content = Map.put(block["content"], "items", items)
    persist(socket, %{blocks: Blocks.put_content(socket.assigns.blocks, id, content)})
  end

  def handle_event("remove_asset", %{"block" => id, "asset" => asset}, socket) do
    result =
      SalesRooms.detach(
        socket.assigns.current_user.id,
        socket.assigns.profile.id,
        socket.assigns.booking_page_id,
        socket.assigns.meeting_type_id,
        id,
        asset
      )

    {:noreply, apply_result(socket, result)}
  end

  def handle_event("stage_upload", %{"block" => id, "kind" => kind}, socket) do
    {:noreply, assign(socket, upload_block: id, upload_kind: kind)}
  end

  def handle_event("cancel_upload", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:block, Blocks.find(assigns.blocks, assigns.selected))
      |> assign(:preview_room, %{
        id: 0,
        blocks: Blocks.presentable(assigns.blocks)
      })

    ~H"""
    <section class="sr-editor" id={@id} data-testid="sales-room-editor">
      <header class="sr-editor__head">
        <div>
          <h2>{dgettext("sales_room", "Sales room")}</h2>
          <p class="gos-plan-muted">
            {dgettext(
              "sales_room",
              "A short page beside the calendar. One promise, a little proof, then a time. Turn a block off and the calendar stays."
            )}
          </p>
        </div>
        <p :if={@allowed} class="sr-editor__stats" data-testid="sales-room-stats">
          {dgettext("sales_room", "%{views} page views", views: @page_views)} · {dgettext(
            "sales_room",
            "%{downloads} PDF downloads",
            downloads: @downloads
          )}
        </p>
      </header>

      <div :if={!@allowed} class="sr-upgrade" data-testid="sales-room-upgrade">
        <p>
          {dgettext(
            "sales_room",
            "Sales room blocks are part of Pro. Free keeps the classic booking page. A downgrade hides the blocks and deletes nothing."
          )}
        </p>
        <.link navigate={~p"/dashboard/plan"} class="action-button action-button--primary">
          {dgettext("sales_room", "See Pro")}
        </.link>
      </div>

      <p :if={@error} class="sr-editor__error" data-testid="sales-room-error">{error_text(@error)}</p>

      <div class="sr-editor__grid">
        <aside class="sr-editor__nav">
          <form id="sales-room-page" phx-change="page" phx-target={@myself}>
            <label>
              {dgettext("sales_room", "Booking page")}
              <select name="booking_page_id">
                <option value="" selected={is_nil(@booking_page_id)}>
                  {dgettext("sales_room", "Your link")}
                </option>
                <option :for={page <- @pages} value={page.id} selected={@booking_page_id == page.id}>
                  {page.name}
                </option>
              </select>
            </label>
          </form>

          <form id="sales-room-scope" phx-change="scope" phx-target={@myself}>
            <label>
              {dgettext("sales_room", "Event type")}
              <select name="meeting_type_id">
                <option value="" selected={is_nil(@meeting_type_id)}>
                  {dgettext("sales_room", "Whole page")}
                </option>
                <option :for={type <- @types} value={type.id} selected={@meeting_type_id == type.id}>
                  {type.name}
                </option>
              </select>
            </label>
          </form>

          <form :if={@meeting_type_id} id="sales-room-override" phx-change="override" phx-target={@myself}>
            <label class="sr-editor__check">
              <input type="hidden" name="override" value="false" />
              <input
                type="checkbox"
                name="override"
                value="true"
                checked={@override}
                disabled={!@allowed}
              />
              {dgettext("sales_room", "Own blocks for this event type")}
            </label>
          </form>

          <ol class="sr-editor__blocks">
            <li :for={{block, index} <- Enum.with_index(@blocks)} class={block["enabled"] && "is-on"}>
              <button
                type="button"
                phx-click="select"
                phx-target={@myself}
                phx-value-id={block["id"]}
                aria-current={block["id"] == @selected && "true"}
              >
                {block_label(block["type"])}
              </button>
              <button
                type="button"
                phx-click="toggle"
                phx-target={@myself}
                phx-value-id={block["id"]}
                disabled={!@allowed}
                data-testid={"sales-room-toggle-#{block["id"]}"}
              >
                {if block["enabled"],
                  do: dgettext("sales_room", "On"),
                  else: dgettext("sales_room", "Off")}
              </button>
              <button
                type="button"
                phx-click="move"
                phx-target={@myself}
                phx-value-id={block["id"]}
                phx-value-dir="up"
                disabled={!@allowed or index == 0}
                aria-label={dgettext("sales_room", "Move up")}
              >
                ↑
              </button>
              <button
                type="button"
                phx-click="move"
                phx-target={@myself}
                phx-value-id={block["id"]}
                phx-value-dir="down"
                disabled={!@allowed or index == length(@blocks) - 1}
                aria-label={dgettext("sales_room", "Move down")}
              >
                ↓
              </button>
            </li>
          </ol>

          <form id="sales-room-accent" phx-change="accent" phx-target={@myself}>
            <label>
              {dgettext("sales_room", "Accent colour")}
              <input
                type="color"
                name="accent"
                value={@accent || "#469189"}
                disabled={!@allowed}
                data-testid="sales-room-accent"
              />
            </label>
          </form>
        </aside>

        <div class="sr-editor__main">
          <.block_fields
            :if={@block}
            block={@block}
            myself={@myself}
            allowed={@allowed}
            uploads={@uploads}
          />
          <div class="sr-editor__preview" data-testid="sales-room-preview">
            <p class="gos-plan-muted">{dgettext("sales_room", "Preview")}</p>
            <Story.blocks
              room={@preview_room}
              profile={@profile}
              calendar_href="#when-step"
              count?={false}
            />
          </div>
        </div>
      </div>

      <iframe
        :if={@profile.username}
        class="sr-editor__frame"
        title={dgettext("sales_room", "Booking page")}
        src={preview_src(@profile, @meeting_type, @revision)}
        data-testid="sales-room-frame"
      />
    </section>
    """
  end

  attr :block, :map, required: true
  attr :myself, :any, required: true
  attr :allowed, :boolean, required: true
  attr :uploads, :map, required: true

  defp block_fields(assigns) do
    ~H"""
    <form
      class="sr-editor__form"
      phx-change="save_block"
      phx-target={@myself}
      id={"sales-room-form-#{@block["id"]}"}
    >
      <input type="hidden" name="block_id" value={@block["id"]} />
      <h3>{block_label(@block["type"])}</h3>
      <.fields block={@block} myself={@myself} allowed={@allowed} />
    </form>
    <.upload_field
      :if={@block["type"] in ["hero", "gallery", "video", "brochures", "logos"]}
      myself={@myself}
      block={@block["id"]}
      kind={upload_kind_name(@block["type"])}
      uploads={@uploads}
      allowed={@allowed}
    />
    """
  end

  defp fields(%{block: %{"type" => "hero"}} = assigns) do
    ~H"""
    <label>
      {dgettext("sales_room", "Headline")}
      <input type="text" name="headline" value={@block["content"]["headline"]} disabled={!@allowed} />
    </label>
    <label>
      {dgettext("sales_room", "Subline")}
      <textarea name="subline" rows="3" disabled={!@allowed}>{@block["content"]["subline"]}</textarea>
    </label>
    <label class="sr-editor__check">
      <input
        type="checkbox"
        name="show_profile_image"
        value="true"
        checked={@block["content"]["show_profile_image"]}
        disabled={!@allowed}
      />
      {dgettext("sales_room", "Show profile photo when there is no logo")}
    </label>
    <label>
      {dgettext("sales_room", "Logo alt text")}
      <input type="text" name="logo_alt" value={@block["content"]["logo_alt"]} disabled={!@allowed} />
    </label>
    <button
      :if={@block["content"]["logo_path"]}
      type="button"
      phx-click="remove_asset"
      phx-target={@myself}
      phx-value-block={@block["id"]}
      phx-value-asset="logo"
      disabled={!@allowed}
    >
      {dgettext("sales_room", "Remove logo")}
    </button>
    """
  end

  defp fields(%{block: %{"type" => "benefits"}} = assigns) do
    ~H"""
    <p class="gos-plan-muted">{dgettext("sales_room", "Three to five short points.")}</p>
    <label :for={item <- @block["content"]["items"]}>
      <input
        type="text"
        name={"items[#{item["id"]}][text]"}
        value={item["text"]}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_item"
        phx-target={@myself}
        phx-value-id={@block["id"]}
        phx-value-item={item["id"]}
        disabled={!@allowed}
      >
        {dgettext("sales_room", "Remove")}
      </button>
    </label>
    <button
      type="button"
      phx-click="add_item"
      phx-target={@myself}
      phx-value-id={@block["id"]}
      disabled={!@allowed or length(@block["content"]["items"]) >= 5}
    >
      {dgettext("sales_room", "Add point")}
    </button>
    """
  end

  defp fields(%{block: %{"type" => "gallery"}} = assigns) do
    ~H"""
    <p class="gos-plan-muted">
      {dgettext("sales_room", "Up to 8 pictures. Each one needs an alt text.")}
    </p>
    <div :for={image <- @block["content"]["images"]} class="sr-editor__asset">
      <img :if={image["path"]} src={"/uploads/" <> image["path"]} alt="" />
      <input
        type="text"
        name={"images[#{image["id"]}][alt]"}
        value={image["alt"]}
        placeholder={dgettext("sales_room", "Alt text")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_asset"
        phx-target={@myself}
        phx-value-block={@block["id"]}
        phx-value-asset={image["id"]}
        disabled={!@allowed}
      >
        {dgettext("sales_room", "Remove")}
      </button>
    </div>
    """
  end

  defp fields(%{block: %{"type" => "video"}} = assigns) do
    ~H"""
    <label>
      {dgettext("sales_room", "YouTube, Vimeo or Loom URL")}
      <input type="url" name="url" value={@block["content"]["url"]} disabled={!@allowed} />
    </label>
    <label>
      {dgettext("sales_room", "Title")}
      <input type="text" name="title" value={@block["content"]["title"]} disabled={!@allowed} />
    </label>
    <p class="gos-plan-muted">{dgettext("sales_room", "Or upload an MP4, up to 50 MB.")}</p>
    <button
      :if={@block["content"]["mp4_path"]}
      type="button"
      phx-click="remove_asset"
      phx-target={@myself}
      phx-value-block={@block["id"]}
      phx-value-asset="mp4"
      disabled={!@allowed}
    >
      {dgettext("sales_room", "Remove video")}
    </button>
    """
  end

  defp fields(%{block: %{"type" => "brochures"}} = assigns) do
    ~H"""
    <p class="gos-plan-muted">{dgettext("sales_room", "Up to 5 PDFs, 20 MB each.")}</p>
    <div :for={file <- @block["content"]["files"]} class="sr-editor__asset">
      <input
        type="text"
        name={"files[#{file["id"]}][title]"}
        value={file["title"]}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_asset"
        phx-target={@myself}
        phx-value-block={@block["id"]}
        phx-value-asset={file["id"]}
        disabled={!@allowed}
      >
        {dgettext("sales_room", "Remove")}
      </button>
    </div>
    """
  end

  defp fields(%{block: %{"type" => "testimonials"}} = assigns) do
    ~H"""
    <fieldset :for={item <- @block["content"]["items"]}>
      <textarea name={"items[#{item["id"]}][quote]"} rows="3" disabled={!@allowed}>{item["quote"]}</textarea>
      <input
        type="text"
        name={"items[#{item["id"]}][name]"}
        value={item["name"]}
        placeholder={dgettext("sales_room", "Name")}
        disabled={!@allowed}
      />
      <input
        type="text"
        name={"items[#{item["id"]}][role]"}
        value={item["role"]}
        placeholder={dgettext("sales_room", "Role")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_item"
        phx-target={@myself}
        phx-value-id={@block["id"]}
        phx-value-item={item["id"]}
        disabled={!@allowed}
      >
        {dgettext("sales_room", "Remove")}
      </button>
    </fieldset>
    <button
      type="button"
      phx-click="add_item"
      phx-target={@myself}
      phx-value-id={@block["id"]}
      disabled={!@allowed}
    >
      {dgettext("sales_room", "Add quote")}
    </button>
    """
  end

  defp fields(%{block: %{"type" => "logos"}} = assigns) do
    ~H"""
    <div :for={item <- @block["content"]["items"]} class="sr-editor__asset">
      <img :if={item["path"]} src={"/uploads/" <> item["path"]} alt="" />
      <input
        type="text"
        name={"items[#{item["id"]}][alt]"}
        value={item["alt"]}
        placeholder={dgettext("sales_room", "Alt text")}
        disabled={!@allowed}
      />
      <input
        type="text"
        name={"items[#{item["id"]}][name]"}
        value={item["name"]}
        placeholder={dgettext("sales_room", "Name")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_asset"
        phx-target={@myself}
        phx-value-block={@block["id"]}
        phx-value-asset={item["id"]}
        disabled={!@allowed}
      >
        {dgettext("sales_room", "Remove")}
      </button>
    </div>
    """
  end

  defp fields(%{block: %{"type" => "faq"}} = assigns) do
    ~H"""
    <fieldset :for={item <- @block["content"]["items"]}>
      <input
        type="text"
        name={"items[#{item["id"]}][question]"}
        value={item["question"]}
        placeholder={dgettext("sales_room", "Question")}
        disabled={!@allowed}
      />
      <textarea name={"items[#{item["id"]}][answer]"} rows="3" disabled={!@allowed}>{item["answer"]}</textarea>
      <button
        type="button"
        phx-click="remove_item"
        phx-target={@myself}
        phx-value-id={@block["id"]}
        phx-value-item={item["id"]}
        disabled={!@allowed}
      >
        {dgettext("sales_room", "Remove")}
      </button>
    </fieldset>
    <button
      type="button"
      phx-click="add_item"
      phx-target={@myself}
      phx-value-id={@block["id"]}
      disabled={!@allowed}
    >
      {dgettext("sales_room", "Add question")}
    </button>
    """
  end

  defp fields(%{block: %{"type" => "cta"}} = assigns) do
    ~H"""
    <label>
      {dgettext("sales_room", "Headline")}
      <input type="text" name="headline" value={@block["content"]["headline"]} disabled={!@allowed} />
    </label>
    <label>
      {dgettext("sales_room", "Text")}
      <textarea name="text" rows="3" disabled={!@allowed}>{@block["content"]["text"]}</textarea>
    </label>
    <label>
      {dgettext("sales_room", "Button")}
      <input
        type="text"
        name="button_label"
        value={@block["content"]["button_label"]}
        disabled={!@allowed}
      />
    </label>
    """
  end

  defp fields(assigns), do: ~H""

  attr :myself, :any, required: true
  attr :block, :string, required: true
  attr :kind, :string, required: true
  attr :uploads, :map, required: true
  attr :allowed, :boolean, required: true

  defp upload_field(assigns) do
    ~H"""
    <form id={"sales-room-upload-#{@block}"} phx-change="stage_upload" phx-target={@myself}>
      <input type="hidden" name="block" value={@block} />
      <input type="hidden" name="kind" value={@kind} />
      <.live_file_input upload={@uploads.asset} disabled={!@allowed} />
    </form>
    """
  end

  defp boot(socket) do
    profile = socket.assigns.profile
    user = socket.assigns.current_user

    socket
    |> assign(:pages, BookingPageQueries.list_for_profile(profile.id))
    |> assign(:types, MeetingTypeQueries.list_active_meeting_types(user.id))
    |> assign(:booking_page_id, nil)
    |> assign(:meeting_type_id, nil)
    |> assign(:selected, "hero")
    |> assign(:revision, 0)
    |> assign(:error, nil)
    |> assign(:allowed, SalesRooms.allowed?(user.id))
    |> assign(:upload_block, nil)
    |> assign(:upload_kind, nil)
    |> reload()
  end

  defp reload(socket) do
    room =
      SalesRooms.get(
        socket.assigns.profile.id,
        socket.assigns.booking_page_id,
        socket.assigns.meeting_type_id
      )

    doc = SalesRooms.editor_document(room)
    type = Enum.find(socket.assigns.types, &(&1.id == socket.assigns.meeting_type_id))

    socket
    |> assign(:blocks, doc.blocks)
    |> assign(:accent, doc.accent)
    |> assign(:override, doc.override)
    |> assign(:page_views, doc.page_views)
    |> assign(:downloads, downloads(doc.download_counts))
    |> assign(:meeting_type, type)
  end

  defp persist(socket, attrs) do
    {:noreply, apply_result(socket, save(socket, attrs))}
  end

  defp save(socket, attrs) do
    SalesRooms.save(
      socket.assigns.current_user.id,
      socket.assigns.profile.id,
      socket.assigns.booking_page_id,
      socket.assigns.meeting_type_id,
      attrs
    )
  end

  defp apply_result(socket, {:ok, _room}) do
    socket
    |> reload()
    |> assign(:error, nil)
    |> update(:revision, &(&1 + 1))
  end

  defp apply_result(socket, {:error, reason}), do: assign(socket, :error, reason)

  defp allow_asset_upload(socket) do
    if socket.assigns[:uploads] && socket.assigns.uploads[:asset] do
      socket
    else
      allow_upload(socket, :asset,
        accept: ~w(.jpg .jpeg .png .webp .pdf .mp4),
        max_entries: 1,
        max_file_size: SalesRooms.Storage.video_limit(),
        auto_upload: true,
        progress: &handle_progress/3
      )
    end
  end

  defp handle_progress(:asset, entry, socket) do
    if entry.done? do
      consume(socket)
    else
      {:noreply, socket}
    end
  end

  defp consume(socket) do
    kind = upload_kind(socket.assigns.upload_kind)

    results =
      consume_uploaded_entries(socket, :asset, fn meta, entry ->
        result =
          SalesRooms.attach(
            socket.assigns.current_user.id,
            socket.assigns.profile.id,
            socket.assigns.booking_page_id,
            socket.assigns.meeting_type_id,
            socket.assigns.upload_block,
            kind,
            meta.path,
            Path.basename(entry.client_name)
          )

        {:ok, result}
      end)

    socket =
      case List.first(results) do
        {:ok, _} -> apply_result(socket, {:ok, :stored})
        {:error, reason} -> apply_result(socket, {:error, reason})
        _ -> socket
      end

    {:noreply, socket}
  end

  defp upload_kind("image"), do: :image
  defp upload_kind("video"), do: :video
  defp upload_kind("pdf"), do: :pdf
  defp upload_kind(_), do: :image

  defp content_from(%{"type" => "hero"}, params) do
    %{
      "headline" => params["headline"],
      "subline" => params["subline"],
      "logo_alt" => params["logo_alt"],
      "show_profile_image" => params["show_profile_image"] == "true"
    }
  end

  defp content_from(%{"type" => "benefits", "content" => content}, params) do
    %{"items" => merge_items(content["items"], params["items"], ["text"])}
  end

  defp content_from(%{"type" => "gallery", "content" => content}, params) do
    %{"images" => merge_items(content["images"], params["images"], ["alt"])}
  end

  defp content_from(%{"type" => "video"}, params) do
    %{"url" => params["url"], "title" => params["title"]}
  end

  defp content_from(%{"type" => "brochures", "content" => content}, params) do
    %{"files" => merge_items(content["files"], params["files"], ["title"])}
  end

  defp content_from(%{"type" => "testimonials", "content" => content}, params) do
    %{"items" => merge_items(content["items"], params["items"], ["quote", "name", "role"])}
  end

  defp content_from(%{"type" => "logos", "content" => content}, params) do
    %{"items" => merge_items(content["items"], params["items"], ["alt", "name"])}
  end

  defp content_from(%{"type" => "faq", "content" => content}, params) do
    %{"items" => merge_items(content["items"], params["items"], ["question", "answer"])}
  end

  defp content_from(%{"type" => "cta"}, params) do
    %{
      "headline" => params["headline"],
      "text" => params["text"],
      "button_label" => params["button_label"]
    }
  end

  defp content_from(_, _), do: %{}

  defp merge_items(current, nil, _keys), do: current || []

  defp merge_items(current, incoming, keys) when is_map(incoming) do
    Enum.map(current || [], fn item ->
      patch = incoming[item["id"]] || %{}
      Enum.reduce(keys, item, fn key, acc -> Map.put(acc, key, patch[key] || acc[key]) end)
    end)
  end

  defp merge_items(current, _, _), do: current || []

  defp blank_item("benefits"), do: %{"id" => random_id(), "text" => ""}

  defp blank_item("testimonials"),
    do: %{"id" => random_id(), "quote" => "", "name" => "", "role" => ""}

  defp blank_item("faq"), do: %{"id" => random_id(), "question" => "", "answer" => ""}
  defp blank_item(_), do: %{"id" => random_id()}

  defp blank_id(""), do: nil
  defp blank_id(nil), do: nil

  defp blank_id(id) do
    case Integer.parse(to_string(id)) do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp downloads(map) when is_map(map) do
    map
    |> Map.values()
    |> Enum.map(fn
      n when is_integer(n) ->
        n

      n when is_binary(n) ->
        case Integer.parse(n) do
          {parsed, ""} -> parsed
          _ -> 0
        end

      _ ->
        0
    end)
    |> Enum.sum()
  end

  defp downloads(_), do: 0

  defp preview_src(profile, type, revision) do
    path =
      if type && profile.username do
        Addresses.meeting_type_path(profile, type)
      else
        "/" <> (profile.username || "")
      end

    path <> "?preview=1&sr=#{revision}"
  end

  defp block_label("hero"), do: dgettext("sales_room", "Hero")
  defp block_label("benefits"), do: dgettext("sales_room", "Benefits")
  defp block_label("gallery"), do: dgettext("sales_room", "Gallery")
  defp block_label("video"), do: dgettext("sales_room", "Video")
  defp block_label("brochures"), do: dgettext("sales_room", "Brochures")
  defp block_label("testimonials"), do: dgettext("sales_room", "Testimonials")
  defp block_label("logos"), do: dgettext("sales_room", "Logos")
  defp block_label("faq"), do: dgettext("sales_room", "FAQ")
  defp block_label("cta"), do: dgettext("sales_room", "Closing")
  defp block_label(_), do: dgettext("sales_room", "Block")

  defp upload_kind_name("video"), do: "video"
  defp upload_kind_name("brochures"), do: "pdf"
  defp upload_kind_name(_), do: "image"

  defp error_text(:upgrade_required),
    do: dgettext("sales_room", "Pro is required to save a sales room.")

  defp error_text(:embed_not_allowed),
    do: dgettext("sales_room", "Only YouTube, Vimeo and Loom links can be embedded.")

  defp error_text([{:video, :embed_not_allowed} | _]),
    do: error_text(:embed_not_allowed)

  defp error_text(:too_large),
    do: dgettext("sales_room", "That file is over the size limit.")

  defp error_text(:too_many),
    do: dgettext("sales_room", "That block is full.")

  defp error_text(:invalid_pdf),
    do: dgettext("sales_room", "Upload a PDF without scripts.")

  defp error_text(:invalid_image),
    do: dgettext("sales_room", "Upload a JPEG, PNG or WebP image.")

  defp error_text(:invalid_video),
    do: dgettext("sales_room", "Upload an MP4 or WebM video.")

  defp error_text(_),
    do: dgettext("sales_room", "That change could not be saved.")

  defp random_id, do: 8 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
end
