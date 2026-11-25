defmodule TymeslotWeb.SalesRooms.Story do
  @moduledoc """
  The sales-room column on a booking page. Every string the host wrote is
  escaped. Video iframes use only the allowlisted src.
  """

  use TymeslotWeb, :html
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Demo
  alias Tymeslot.SalesRooms.Embeds

  attr :room, :map, required: true
  attr :profile, :map, default: nil
  attr :locale, :string, default: "en"
  attr :calendar_href, :string, default: "#when-step"
  attr :count?, :boolean, default: true

  def blocks(assigns) do
    blocks = assigns.room.blocks || []

    assigns =
      assigns
      |> assign(:blocks, blocks)
      |> assign(:button, button_label(blocks))

    ~H"""
    <div class="sr-story" data-testid="sales-room" data-host-room="on">
      <%= for block <- @blocks do %>
        {render_block(block, assigns)}
      <% end %>
      <a class="sr-book-tab" href={@calendar_href} data-testid="sales-room-book">
        {@button}
      </a>
      <.live_component
        :if={@count?}
        module={TymeslotWeb.SalesRooms.ViewCounter}
        id={"sales-room-views-#{@room.id}"}
        room_id={@room.id}
      />
    </div>
    """
  end

  defp render_block(%{"type" => "hero", "content" => content}, assigns) do
    assigns = assign(assigns, :content, content)

    ~H"""
    <header class="sr-hero">
      <img
        :if={@content["logo_path"]}
        class="sr-hero__logo"
        src={file_src(@content["logo_path"])}
        alt={@content["logo_alt"]}
      />
      <img
        :if={!@content["logo_path"] and @content["show_profile_image"] and @profile}
        class="sr-hero__portrait"
        src={Demo.avatar_url(@profile, :original)}
        alt={Demo.avatar_alt_text(@profile)}
      />
      <h2 :if={@content["headline"] != ""} class="sr-hero__title">{@content["headline"]}</h2>
      <p :if={@content["subline"] != ""} class="sr-hero__sub">{@content["subline"]}</p>
    </header>
    """
  end

  defp render_block(%{"type" => "benefits", "content" => content}, assigns) do
    items = Enum.filter(content["items"] || [], &text?(&1["text"]))
    assigns = assign(assigns, :items, items)

    ~H"""
    <section class="sr-card" data-testid="sales-room-benefits">
      <h3>{dgettext("sales_room", "What you leave with")}</h3>
      <ul class="sr-benefits">
        <li :for={item <- @items}>{item["text"]}</li>
      </ul>
    </section>
    """
  end

  defp render_block(%{"type" => "gallery", "content" => content}, assigns) do
    images = Enum.filter(content["images"] || [], &(text?(&1["path"]) and text?(&1["alt"])))
    assigns = assign(assigns, :images, images)

    ~H"""
    <section class="sr-card" data-testid="sales-room-gallery">
      <h3>{dgettext("sales_room", "In pictures")}</h3>
      <ul class="sr-gallery">
        <li :for={image <- @images}>
          <img src={file_src(image["path"])} alt={image["alt"]} />
        </li>
      </ul>
    </section>
    """
  end

  defp render_block(%{"type" => "video", "content" => content}, assigns) do
    src =
      case Embeds.iframe_src(content["url"]) do
        {:ok, src} -> src
        :error -> nil
      end

    assigns = assign(assigns, content: content, src: src)

    ~H"""
    <section class="sr-card" data-testid="sales-room-video">
      <h3>{(@content["title"] != "" && @content["title"]) || dgettext("sales_room", "Watch")}</h3>
      <iframe
        :if={@src}
        src={@src}
        title={@content["title"]}
        loading="lazy"
        referrerpolicy="no-referrer"
        allow="fullscreen; picture-in-picture"
        allowfullscreen
      />
      <video
        :if={!@src and @content["mp4_path"]}
        controls
        preload="metadata"
        src={file_src(@content["mp4_path"])}
      >
        {dgettext("sales_room", "Watch")}
      </video>
    </section>
    """
  end

  defp render_block(%{"type" => "brochures", "content" => content}, assigns) do
    files = Enum.filter(content["files"] || [], &text?(&1["path"]))
    assigns = assign(assigns, :files, files)

    ~H"""
    <section class="sr-card" data-testid="sales-room-brochures">
      <h3>{dgettext("sales_room", "Documents")}</h3>
      <ul class="sr-files">
        <li :for={file <- @files}>
          <a href={download_path(@room.id, file["id"])}>
            <span>{(file["title"] != "" && file["title"]) || file["filename"]}</span>
            <small>PDF</small>
          </a>
        </li>
      </ul>
    </section>
    """
  end

  defp render_block(%{"type" => "testimonials", "content" => content}, assigns) do
    items = Enum.filter(content["items"] || [], &(text?(&1["quote"]) and text?(&1["name"])))
    assigns = assign(assigns, :items, items)

    ~H"""
    <section class="sr-card" data-testid="sales-room-testimonials">
      <h3>{dgettext("sales_room", "What clients say")}</h3>
      <ul class="sr-quotes">
        <li :for={item <- @items}>
          <blockquote>{item["quote"]}</blockquote>
          <p>
            <strong>{item["name"]}</strong>
            <span :if={item["role"] != ""}>{item["role"]}</span>
          </p>
        </li>
      </ul>
    </section>
    """
  end

  defp render_block(%{"type" => "logos", "content" => content}, assigns) do
    items = Enum.filter(content["items"] || [], &(text?(&1["path"]) and text?(&1["alt"])))
    assigns = assign(assigns, :items, items)

    ~H"""
    <section class="sr-card sr-card--logos" data-testid="sales-room-logos">
      <h3>{dgettext("sales_room", "Trusted by")}</h3>
      <ul class="sr-logos">
        <li :for={item <- @items}>
          <img src={file_src(item["path"])} alt={item["alt"]} />
        </li>
      </ul>
    </section>
    """
  end

  defp render_block(%{"type" => "faq", "content" => content}, assigns) do
    items = Enum.filter(content["items"] || [], &(text?(&1["question"]) and text?(&1["answer"])))
    assigns = assign(assigns, :items, items)

    ~H"""
    <section class="sr-card" data-testid="sales-room-faq">
      <h3>{dgettext("sales_room", "Questions")}</h3>
      <div class="sr-faq">
        <details :for={item <- @items}>
          <summary>{item["question"]}</summary>
          <p>{item["answer"]}</p>
        </details>
      </div>
    </section>
    """
  end

  defp render_block(%{"type" => "cta", "content" => content}, assigns) do
    label =
      if content["button_label"] == "",
        do: dgettext("sales_room", "Choose a time"),
        else: content["button_label"]

    assigns = assign(assigns, content: content, label: label)

    ~H"""
    <section class="sr-cta" data-testid="sales-room-cta">
      <h3 :if={@content["headline"] != ""}>{@content["headline"]}</h3>
      <p :if={@content["text"] != ""}>{@content["text"]}</p>
      <a class="sr-cta__button" href={@calendar_href}>{@label}</a>
    </section>
    """
  end

  defp render_block(_, _), do: nil

  defp button_label(blocks) do
    cta = Enum.find(blocks, &(&1["type"] == "cta"))
    label = cta && cta["content"]["button_label"]

    if is_binary(label) and label != "" do
      label
    else
      dgettext("sales_room", "Choose a time")
    end
  end

  defp file_src(path), do: "/uploads/" <> path

  defp download_path(room_id, file_id), do: "/downloads/sales-room/#{room_id}/#{file_id}"

  defp text?(value), do: is_binary(value) and String.trim(value) != ""
end
