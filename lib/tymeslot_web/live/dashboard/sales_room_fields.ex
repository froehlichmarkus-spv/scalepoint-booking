defmodule TymeslotWeb.Dashboard.SalesRoomFields do
  @moduledoc """
  The inputs for one sales-room block. The editor owns saving and uploads;
  this module only draws the fields.
  """

  use TymeslotWeb, :html
  use Gettext, backend: TymeslotWeb.Gettext

  attr :block, :map, required: true
  attr :uploads, :map, required: true
  attr :myself, :any, required: true
  attr :photo_index, :integer, required: true
  attr :allowed, :boolean, required: true

  @spec fields(map()) :: Phoenix.LiveView.Rendered.t()
  def fields(%{block: %{"type" => "hero"}} = assigns) do
    ~H"""
    <.input
      type="text"
      name="headline"
      value={@block["headline"]}
      label={dgettext("dashboard_booking_pages", "Headline")}
      disabled={!@allowed}
    />
    <.input
      type="textarea"
      name="subline"
      value={@block["subline"]}
      label={dgettext("dashboard_booking_pages", "Subline")}
      disabled={!@allowed}
    />
    <.input
      type="text"
      name="image_alt"
      value={@block["image_alt"]}
      label={dgettext("dashboard_booking_pages", "Image description")}
      disabled={!@allowed}
    />
    <.select
      id="sales-room-image-kind"
      name="image_kind"
      label={dgettext("dashboard_booking_pages", "Image")}
      value={@block["image_kind"]}
      disabled={!@allowed}
      options={[
        {dgettext("dashboard_booking_pages", "Portrait"), "portrait"},
        {dgettext("dashboard_booking_pages", "Logo"), "logo"}
      ]}
    />
    <.live_file_input :if={@allowed} upload={@uploads.hero_image} />
    """
  end

  def fields(%{block: %{"type" => "offer"}} = assigns) do
    ~H"""
    <div :for={{item, index} <- Enum.with_index(@block["items"])} class="space-y-2">
      <.input
        type="text"
        name={"title_#{index}"}
        value={item["title"]}
        label={dgettext("dashboard_booking_pages", "Title")}
        disabled={!@allowed}
      />
      <.input
        type="text"
        name={"text_#{index}"}
        value={item["text"]}
        label={dgettext("dashboard_booking_pages", "Text")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_item"
        phx-value-index={index}
        phx-target={@myself}
        disabled={!@allowed}
      >
        {dgettext("dashboard_booking_pages", "Remove")}
      </button>
    </div>
    <button
      type="button"
      phx-click="add_item"
      phx-target={@myself}
      disabled={!@allowed}
      data-testid="sales-room-add-item"
    >
      {dgettext("dashboard_booking_pages", "Add point")}
    </button>
    """
  end

  def fields(%{block: %{"type" => "gallery"}} = assigns) do
    ~H"""
    <div :for={{image, index} <- Enum.with_index(@block["images"])}>
      <.input
        type="text"
        name={"alt_#{index}"}
        value={image["alt"]}
        label={dgettext("dashboard_booking_pages", "Image description")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_item"
        phx-value-index={index}
        phx-target={@myself}
        disabled={!@allowed}
      >
        {dgettext("dashboard_booking_pages", "Remove")}
      </button>
    </div>
    <.live_file_input :if={@allowed} upload={@uploads.gallery_image} />
    <p class="text-token-xs text-tymeslot-500">
      {dgettext("dashboard_booking_pages", "Up to 8 images. JPG, PNG or WebP.")}
    </p>
    """
  end

  def fields(%{block: %{"type" => "video"}} = assigns) do
    ~H"""
    <.input
      type="text"
      name="title"
      value={@block["title"]}
      label={dgettext("dashboard_booking_pages", "Title")}
      disabled={!@allowed}
    />
    <.input
      type="url"
      name="url"
      value={@block["url"]}
      label={dgettext("dashboard_booking_pages", "YouTube, Vimeo or Loom URL")}
      disabled={!@allowed}
    />
    <.live_file_input :if={@allowed} upload={@uploads.video_file} />
    <p class="text-token-xs text-tymeslot-500">
      {dgettext("dashboard_booking_pages", "Or an MP4 or WebM up to 40 MB.")}
    </p>
    """
  end

  def fields(%{block: %{"type" => "documents"}} = assigns) do
    ~H"""
    <div
      :for={{file, index} <- Enum.with_index(@block["files"])}
      class="flex items-center justify-between gap-2"
    >
      <span class="text-token-sm">{file["name"]}</span>
      <button
        type="button"
        phx-click="remove_item"
        phx-value-index={index}
        phx-target={@myself}
        disabled={!@allowed}
      >
        {dgettext("dashboard_booking_pages", "Remove")}
      </button>
    </div>
    <.live_file_input :if={@allowed} upload={@uploads.document_file} />
    <p class="text-token-xs text-tymeslot-500">
      {dgettext("dashboard_booking_pages", "Up to 5 PDFs, 20 MB each.")}
    </p>
    """
  end

  def fields(%{block: %{"type" => "testimonials"}} = assigns) do
    ~H"""
    <div :for={{item, index} <- Enum.with_index(@block["items"])} class="space-y-2">
      <.input
        type="textarea"
        name={"quote_#{index}"}
        value={item["quote"]}
        label={dgettext("dashboard_booking_pages", "Quote")}
        disabled={!@allowed}
      />
      <.input
        type="text"
        name={"name_#{index}"}
        value={item["name"]}
        label={dgettext("dashboard_booking_pages", "Name")}
        disabled={!@allowed}
      />
      <.input
        type="text"
        name={"company_#{index}"}
        value={item["company"]}
        label={dgettext("dashboard_booking_pages", "Company")}
        disabled={!@allowed}
      />
      <.input
        type="text"
        name={"photo_alt_#{index}"}
        value={item["photo_alt"]}
        label={dgettext("dashboard_booking_pages", "Photo description")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="aim_photo"
        phx-value-index={index}
        phx-target={@myself}
        disabled={!@allowed}
      >
        {dgettext("dashboard_booking_pages", "Choose photo")}
      </button>
      <.live_file_input :if={@allowed && @photo_index == index} upload={@uploads.quote_photo} />
      <button
        type="button"
        phx-click="remove_item"
        phx-value-index={index}
        phx-target={@myself}
        disabled={!@allowed}
      >
        {dgettext("dashboard_booking_pages", "Remove")}
      </button>
    </div>
    <button type="button" phx-click="add_item" phx-target={@myself} disabled={!@allowed}>
      {dgettext("dashboard_booking_pages", "Add quote")}
    </button>
    """
  end

  def fields(%{block: %{"type" => "logos"}} = assigns) do
    ~H"""
    <div :for={{logo, index} <- Enum.with_index(@block["items"])}>
      <.input
        type="text"
        name={"alt_#{index}"}
        value={logo["alt"]}
        label={dgettext("dashboard_booking_pages", "Logo description")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_item"
        phx-value-index={index}
        phx-target={@myself}
        disabled={!@allowed}
      >
        {dgettext("dashboard_booking_pages", "Remove")}
      </button>
    </div>
    <.live_file_input :if={@allowed} upload={@uploads.logo_image} />
    """
  end

  def fields(%{block: %{"type" => "faq"}} = assigns) do
    ~H"""
    <div :for={{item, index} <- Enum.with_index(@block["items"])} class="space-y-2">
      <.input
        type="text"
        name={"question_#{index}"}
        value={item["question"]}
        label={dgettext("dashboard_booking_pages", "Question")}
        disabled={!@allowed}
      />
      <.input
        type="textarea"
        name={"answer_#{index}"}
        value={item["answer"]}
        label={dgettext("dashboard_booking_pages", "Answer")}
        disabled={!@allowed}
      />
      <button
        type="button"
        phx-click="remove_item"
        phx-value-index={index}
        phx-target={@myself}
        disabled={!@allowed}
      >
        {dgettext("dashboard_booking_pages", "Remove")}
      </button>
    </div>
    <button type="button" phx-click="add_item" phx-target={@myself} disabled={!@allowed}>
      {dgettext("dashboard_booking_pages", "Add question")}
    </button>
    """
  end

  def fields(%{block: %{"type" => "cta"}} = assigns) do
    ~H"""
    <.input
      type="text"
      name="headline"
      value={@block["headline"]}
      label={dgettext("dashboard_booking_pages", "Headline")}
      disabled={!@allowed}
    />
    <.input
      type="textarea"
      name="text"
      value={@block["text"]}
      label={dgettext("dashboard_booking_pages", "Text")}
      disabled={!@allowed}
    />
    <.input
      type="text"
      name="button"
      value={@block["button"]}
      label={dgettext("dashboard_booking_pages", "Button")}
      disabled={!@allowed}
    />
    """
  end

  @spec label(String.t()) :: String.t()
  def label(id) do
    Map.get(
      %{
        "hero" => dgettext("dashboard_booking_pages", "Hero"),
        "offer" => dgettext("dashboard_booking_pages", "Offer"),
        "gallery" => dgettext("dashboard_booking_pages", "Gallery"),
        "video" => dgettext("dashboard_booking_pages", "Video"),
        "documents" => dgettext("dashboard_booking_pages", "Documents"),
        "testimonials" => dgettext("dashboard_booking_pages", "Testimonials"),
        "logos" => dgettext("dashboard_booking_pages", "Logos"),
        "faq" => dgettext("dashboard_booking_pages", "Questions"),
        "cta" => dgettext("dashboard_booking_pages", "Closing call")
      },
      id,
      id
    )
  end

  @spec error_text(term()) :: String.t()
  def error_text(:pro_required),
    do: dgettext("dashboard_booking_pages", "Sales room is part of Pro")

  def error_text(:alt_required),
    do: dgettext("dashboard_booking_pages", "Describe each image before saving it.")

  def error_text(:too_many_items), do: dgettext("dashboard_booking_pages", "That block is full.")

  def error_text(:invalid_image_format),
    do: dgettext("dashboard_booking_pages", "Use a JPG, PNG or WebP image.")

  def error_text(:invalid_video_format),
    do: dgettext("dashboard_booking_pages", "Use an MP4 or WebM video.")

  def error_text(:invalid_pdf), do: dgettext("dashboard_booking_pages", "Use a PDF.")
  def error_text(:too_large), do: dgettext("dashboard_booking_pages", "That file is too large.")
  def error_text(_other), do: dgettext("dashboard_booking_pages", "Could not save this block.")
end
