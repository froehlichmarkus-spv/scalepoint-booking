defmodule TymeslotWeb.SalesRooms.Public do
  @moduledoc """
  The visitor-facing sales room. It sits beside the calendar on a wide
  screen and above it on a phone, where a button leads to the slots.
  """

  use Phoenix.Component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Demo
  alias Tymeslot.Profiles
  alias Tymeslot.SalesRooms.Storage

  attr :blocks, :list, required: true
  attr :profile, :map, default: nil
  attr :locale, :string, default: "en"
  attr :preview, :boolean, default: false

  @spec story(map()) :: Phoenix.LiveView.Rendered.t()
  def story(assigns) do
    assigns =
      assigns
      |> assign(:host, host_name(assigns.profile))
      |> assign(:pick, pick_label(assigns.blocks, assigns.locale))

    ~H"""
    <div class="host-room" data-testid="host-room">
      <%= for block <- @blocks do %>
        <.block block={block} host={@host} locale={@locale} profile={@profile} preview={@preview} />
      <% end %>
      <a href="#host-room-book" class="host-room__pick" data-testid="host-room-pick">
        {@pick}
      </a>
    </div>
    """
  end

  attr :block, :map, required: true
  attr :host, :string, default: nil
  attr :locale, :string, default: "en"
  attr :profile, :map, default: nil
  attr :preview, :boolean, default: false

  defp block(%{block: %{"type" => "hero"}} = assigns) do
    image = image_src(assigns.block["image_path"], assigns.preview)
    kind = assigns.block["image_kind"] || "portrait"

    assigns =
      assigns
      |> assign(:image, image)
      |> assign(:kind, kind)
      |> assign(:fallback, fallback_portrait(assigns.profile, image))

    ~H"""
    <header class="host-room__hero" data-testid="host-room-hero">
      <img
        :if={@image}
        class={["host-room__portrait", @kind == "logo" && "host-room__portrait--logo"]}
        src={@image}
        alt={@block["image_alt"]}
      />
      <img :if={!@image && @fallback} class="host-room__portrait" src={@fallback} alt="" />
      <p :if={@host} class="host-room__eyebrow">{@host}</p>
      <h1 class="host-room__headline">{@block["headline"]}</h1>
      <p :if={@block["subline"]} class="host-room__subline">{@block["subline"]}</p>
    </header>
    """
  end

  defp block(%{block: %{"type" => "offer"}} = assigns) do
    ~H"""
    <section class="host-room__section" data-testid="host-room-offer">
      <h2 class="host-room__title">{dgettext("booking", "The offer")}</h2>
      <ul class="host-room__offer">
        <li :for={item <- @block["items"]}>
          <strong :if={item["title"]}>{item["title"]}</strong>
          <span :if={item["text"]}>{item["text"]}</span>
        </li>
      </ul>
    </section>
    """
  end

  defp block(%{block: %{"type" => "gallery"}} = assigns) do
    ~H"""
    <section class="host-room__section" data-testid="host-room-gallery">
      <ul class="host-room__gallery">
        <li :for={image <- @block["images"]}>
          <img src={image_src(image["path"], @preview)} alt={image["alt"]} />
        </li>
      </ul>
    </section>
    """
  end

  defp block(%{block: %{"type" => "video"}} = assigns) do
    title = assigns.block["title"] || dgettext("booking", "Film")

    assigns = assign(assigns, :title, title)

    ~H"""
    <section class="host-room__section" data-testid="host-room-video">
      <h2 :if={@block["title"]} class="host-room__title">{@block["title"]}</h2>
      <div class="host-room__frame">
        <iframe
          :if={@block["embed_src"]}
          src={@block["embed_src"]}
          title={@title}
          loading="lazy"
          referrerpolicy="strict-origin-when-cross-origin"
          allow="fullscreen; picture-in-picture"
          allowfullscreen
        ></iframe>
        <video
          :if={@block["file_path"]}
          src={image_src(@block["file_path"], @preview)}
          controls
          preload="metadata"
          aria-label={@title}
        ></video>
      </div>
    </section>
    """
  end

  defp block(%{block: %{"type" => "documents"}} = assigns) do
    ~H"""
    <section class="host-room__section" data-testid="host-room-documents">
      <h2 class="host-room__title">{dgettext("booking", "Documents")}</h2>
      <ul class="host-room__files">
        <li :for={file <- @block["files"]}>
          <a href={download_href(@profile, file)} data-testid="host-room-download">
            <span>{file["name"]}</span>
            <small>{dgettext("booking", "Download")}</small>
          </a>
        </li>
      </ul>
    </section>
    """
  end

  defp block(%{block: %{"type" => "testimonials"}} = assigns) do
    ~H"""
    <section class="host-room__section" data-testid="host-room-testimonials">
      <h2 class="host-room__title">{dgettext("booking", "What clients say")}</h2>
      <ul class="host-room__quotes">
        <li :for={item <- @block["items"]}>
          <blockquote>{item["quote"]}</blockquote>
          <footer>
            <img
              :if={item["photo_path"]}
              src={image_src(item["photo_path"], @preview)}
              alt={item["photo_alt"]}
            />
            <span>
              <strong>{item["name"]}</strong>
              <em :if={item["company"]}>{item["company"]}</em>
            </span>
          </footer>
        </li>
      </ul>
    </section>
    """
  end

  defp block(%{block: %{"type" => "logos"}} = assigns) do
    ~H"""
    <section class="host-room__section" data-testid="host-room-logos">
      <h2 class="host-room__title">{dgettext("booking", "Clients")}</h2>
      <ul class="host-room__logos">
        <li :for={logo <- @block["items"]}>
          <img src={image_src(logo["path"], @preview)} alt={logo["alt"]} />
        </li>
      </ul>
    </section>
    """
  end

  defp block(%{block: %{"type" => "faq"}} = assigns) do
    ~H"""
    <section class="host-room__section" data-testid="host-room-faq">
      <h2 class="host-room__title">{dgettext("booking", "Questions")}</h2>
      <div class="host-room__faq">
        <details :for={item <- @block["items"]}>
          <summary>{item["question"]}</summary>
          <p>{item["answer"]}</p>
        </details>
      </div>
    </section>
    """
  end

  defp block(%{block: %{"type" => "cta"}} = assigns) do
    label = assigns.block["button"] || dgettext("booking", "Choose a time")
    assigns = assign(assigns, :label, label)

    ~H"""
    <section class="host-room__close" data-testid="host-room-cta">
      <h2 :if={@block["headline"]}>{@block["headline"]}</h2>
      <p :if={@block["text"]}>{@block["text"]}</p>
      <a href="#host-room-book" class="host-room__button">{@label}</a>
    </section>
    """
  end

  defp block(assigns) do
    ~H"""
    <span hidden data-type={@block["type"]}></span>
    """
  end

  defp pick_label(blocks, locale) do
    button =
      Enum.find_value(blocks, fn
        %{"type" => "cta", "button" => button} when is_binary(button) and button != "" -> button
        _other -> nil
      end)

    button ||
      Gettext.with_locale(TymeslotWeb.Gettext, locale || "en", fn ->
        dgettext("booking", "Choose a time")
      end)
  end

  defp host_name(profile) do
    case Profiles.display_name(profile) do
      name when is_binary(name) and name != "" -> name
      _missing -> nil
    end
  end

  defp image_src(nil, _preview), do: nil
  defp image_src(path, _preview), do: Storage.public_url(path)

  defp fallback_portrait(_profile, image) when is_binary(image), do: nil

  defp fallback_portrait(%{__struct__: _module} = profile, nil) do
    case Demo.avatar_url(profile, :medium) do
      url when is_binary(url) and url != "" -> url
      _missing -> nil
    end
  end

  defp fallback_portrait(_profile, _image), do: nil

  defp download_href(%{id: profile_id}, %{"path" => path}) when is_integer(profile_id) do
    "/booking-files/#{profile_id}/#{Path.basename(path)}"
  end

  defp download_href(_profile, _file), do: "#"
end
