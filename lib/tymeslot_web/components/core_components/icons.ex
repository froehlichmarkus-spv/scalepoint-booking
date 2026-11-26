defmodule TymeslotWeb.Components.CoreComponents.Icons do
  @moduledoc """
  The one icon component, `<.icon>`, and the renderer behind it.

  Every icon in the app is drawn here, from one of two compile-time sets:
  `hero-*` names from the vendored Heroicons, and the few marks Heroicons does
  not ship (brand logos) from `CustomIcons`. An app layered on top of Core
  keeps its own extra icons in its own set and renders them with `svg/1`, so
  they paint with exactly the same markup.
  """
  use Phoenix.Component

  alias TymeslotWeb.Components.CoreComponents.CustomIcons
  alias TymeslotWeb.Components.CoreComponents.Heroicons
  alias TymeslotWeb.Components.CoreComponents.IconSource

  @doc """
  Renders an icon as inline SVG.

  `hero-{name}` is a Heroicon in its outline style; the `-solid`, `-mini` and
  `-micro` suffixes select the others. Any other name is one of Core's custom
  icons in `priv/icons` (e.g. `brand-slack`).

  Size and colour come from classes (`w-5 h-5 text-turquoise-500`): the icon
  inherits `currentColor`, and with no size class it falls back to its
  intrinsic size (24/20/16px). A stroke-weight class (`stroke-2`) thickens an
  outline icon. An unknown name renders an empty span rather than crashing.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
      <.icon name="brand-slack" class="w-6 h-6" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: nil
  attr :style, :string, default: nil
  attr :rest, :global

  @spec icon(map()) :: Phoenix.LiveView.Rendered.t()
  def icon(assigns) do
    case lucide_id(assigns.name) do
      nil ->
        case fetch(assigns.name) do
          {:ok, icon} -> svg(assign(assigns, :icon, icon))
          :error -> unknown(assigns)
        end

      id ->
        lucide(assign(assigns, :sprite_id, id))
    end
  end

  @lucide_names %{
    "hero-adjustments-horizontal" => "i-settings",
    "hero-adjustments-vertical" => "i-settings",
    "hero-arrow-down-mini" => "i-chevron-down",
    "hero-arrow-down-tray" => "i-chevron-down",
    "hero-arrow-left" => "i-chevron-left",
    "hero-arrow-left-mini" => "i-chevron-left",
    "hero-arrow-path" => "i-refresh-cw",
    "hero-arrow-path-mini" => "i-refresh-cw",
    "hero-arrow-right" => "i-chevron-right",
    "hero-arrow-right-micro" => "i-chevron-right",
    "hero-arrow-right-mini" => "i-chevron-right",
    "hero-arrow-right-on-rectangle" => "i-chevron-right",
    "hero-arrow-top-right-on-square" => "i-external-link",
    "hero-arrow-top-right-on-square-mini" => "i-external-link",
    "hero-arrow-up-tray" => "i-chevron-up",
    "hero-arrow-up-tray-mini" => "i-chevron-up",
    "hero-banknotes" => "i-credit-card",
    "hero-banknotes-mini" => "i-credit-card",
    "hero-bars-2" => "i-menu",
    "hero-bars-3" => "i-menu",
    "hero-bars-3-bottom-left" => "i-menu",
    "hero-bars-4" => "i-menu",
    "hero-bell" => "i-bell",
    "hero-bell-alert" => "i-triangle-alert",
    "hero-bell-alert-mini" => "i-triangle-alert",
    "hero-bell-mini" => "i-bell",
    "hero-bolt" => "i-zap",
    "hero-bolt-mini" => "i-zap",
    "hero-building-office" => "i-map-pin",
    "hero-building-office-2" => "i-map-pin",
    "hero-building-office-mini" => "i-map-pin",
    "hero-calendar" => "i-calendar",
    "hero-calendar-date-range" => "i-calendar",
    "hero-calendar-days" => "i-calendar",
    "hero-calendar-days-mini" => "i-calendar",
    "hero-calendar-mini" => "i-calendar",
    "hero-camera" => "i-video",
    "hero-chart-bar" => "i-chart-column",
    "hero-chat-bubble-bottom-center-text" => "i-message-square",
    "hero-chat-bubble-left" => "i-message-square",
    "hero-chat-bubble-left-ellipsis" => "i-message-square",
    "hero-chat-bubble-left-right" => "i-message-square",
    "hero-check" => "i-check",
    "hero-check-badge-mini" => "i-shield-check",
    "hero-check-circle" => "i-check",
    "hero-check-circle-mini" => "i-check",
    "hero-check-circle-solid" => "i-check",
    "hero-check-micro" => "i-check",
    "hero-check-mini" => "i-check",
    "hero-chevron-double-left" => "i-chevron-left",
    "hero-chevron-double-right" => "i-chevron-right",
    "hero-chevron-down" => "i-chevron-down",
    "hero-chevron-down-mini" => "i-chevron-down",
    "hero-chevron-left" => "i-chevron-left",
    "hero-chevron-left-mini" => "i-chevron-left",
    "hero-chevron-right" => "i-chevron-right",
    "hero-chevron-right-mini" => "i-chevron-right",
    "hero-chevron-up-mini" => "i-chevron-up",
    "hero-clipboard" => "i-copy",
    "hero-clipboard-document" => "i-copy",
    "hero-clock" => "i-clock",
    "hero-clock-mini" => "i-clock",
    "hero-cloud-arrow-up" => "i-chevron-up",
    "hero-code-bracket" => "i-command",
    "hero-cog-6-tooth" => "i-settings",
    "hero-credit-card" => "i-credit-card",
    "hero-credit-card-micro" => "i-credit-card",
    "hero-device-phone-mobile" => "i-phone",
    "hero-document-duplicate" => "i-copy",
    "hero-envelope" => "i-mail",
    "hero-envelope-micro" => "i-mail",
    "hero-envelope-mini" => "i-mail",
    "hero-envelope-open" => "i-mail",
    "hero-exclamation-circle" => "i-triangle-alert",
    "hero-exclamation-circle-mini" => "i-triangle-alert",
    "hero-exclamation-circle-solid" => "i-triangle-alert",
    "hero-exclamation-triangle" => "i-triangle-alert",
    "hero-exclamation-triangle-micro" => "i-triangle-alert",
    "hero-exclamation-triangle-mini" => "i-triangle-alert",
    "hero-eye" => "i-eye",
    "hero-eye-mini" => "i-eye",
    "hero-eye-slash" => "i-eye-off",
    "hero-eye-slash-mini" => "i-eye-off",
    "hero-flag" => "i-globe",
    "hero-globe-alt" => "i-globe",
    "hero-globe-alt-mini" => "i-globe",
    "hero-globe-europe-africa" => "i-globe",
    "hero-home" => "i-layout-dashboard",
    "hero-inbox-arrow-down" => "i-chevron-down",
    "hero-inbox-stack" => "i-inbox",
    "hero-information-circle" => "i-info",
    "hero-information-circle-mini" => "i-info",
    "hero-key" => "i-key-round",
    "hero-language" => "i-globe",
    "hero-link" => "i-link-2",
    "hero-link-mini" => "i-link-2",
    "hero-link-slash" => "i-link-2",
    "hero-lock-closed" => "i-lock",
    "hero-lock-closed-micro" => "i-lock",
    "hero-lock-closed-mini" => "i-lock",
    "hero-magnifying-glass" => "i-search",
    "hero-map-pin" => "i-map-pin",
    "hero-map-pin-micro" => "i-map-pin",
    "hero-map-pin-mini" => "i-map-pin",
    "hero-minus-circle" => "i-minus",
    "hero-minus-mini" => "i-minus",
    "hero-moon" => "i-moon",
    "hero-no-symbol" => "i-x",
    "hero-no-symbol-micro" => "i-x",
    "hero-pause-circle-mini" => "i-server-crash",
    "hero-pencil-square" => "i-pencil",
    "hero-pencil-square-mini" => "i-pencil",
    "hero-phone" => "i-phone",
    "hero-phone-mini" => "i-phone",
    "hero-play-circle" => "i-server-crash",
    "hero-plus" => "i-plus",
    "hero-plus-circle" => "i-plus",
    "hero-plus-mini" => "i-plus",
    "hero-qr-code" => "i-command",
    "hero-question-mark-circle" => "i-circle-help",
    "hero-question-mark-circle-mini" => "i-circle-help",
    "hero-question-mark-circle-solid" => "i-circle-help",
    "hero-shield-check" => "i-shield-check",
    "hero-sparkles-mini" => "i-zap",
    "hero-star" => "i-star",
    "hero-sun" => "i-sun",
    "hero-sun-mini" => "i-sun",
    "hero-trash" => "i-x",
    "hero-trash-mini" => "i-x",
    "hero-user" => "i-user",
    "hero-user-group" => "i-users",
    "hero-user-group-micro" => "i-users",
    "hero-user-group-mini" => "i-users",
    "hero-user-micro" => "i-user",
    "hero-user-mini" => "i-user",
    "hero-user-minus" => "i-user",
    "hero-user-plus" => "i-users",
    "hero-users" => "i-users",
    "hero-users-mini" => "i-users",
    "hero-video-camera" => "i-video",
    "hero-video-camera-mini" => "i-video",
    "hero-x-circle" => "i-x",
    "hero-x-circle-mini" => "i-x",
    "hero-x-circle-solid" => "i-x",
    "hero-x-mark" => "i-x",
    "hero-x-mark-micro" => "i-x",
    "hero-x-mark-mini" => "i-x",
    "hero-x-mark-solid" => "i-x"
  }

  defp lucide_id(name) when is_binary(name) do
    cond do
      Map.has_key?(@lucide_names, name) -> @lucide_names[name]
      String.starts_with?(name, "hero-") -> "i-info"
      true -> nil
    end
  end

  defp lucide_id(_name), do: nil

  attr :sprite_id, :string, required: true
  attr :class, :any, default: nil
  attr :style, :string, default: nil
  attr :rest, :global

  defp lucide(assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      class={["gos-icon", @class]}
      style={@style}
      aria-hidden="true"
      {@rest}
    >
      <use href={"/images/sprite.svg#" <> @sprite_id} />
    </svg>
    """
  end

  @doc "Whether `name` is an icon `<.icon>` can draw."
  @spec known?(String.t()) :: boolean()
  def known?(name), do: lucide_id(name) != nil or fetch(name) != :error

  @doc """
  Draws an already fetched icon (`assigns.icon`, from an `IconSource` set) as
  inline SVG, with `class`, `style` and any global attributes.

  This is the renderer `icon/1` uses; an app with an icon set of its own calls
  it so its icons get identical markup.
  """
  @spec svg(map()) :: Phoenix.LiveView.Rendered.t()
  def svg(assigns) do
    assigns = assign_new(assigns, :rest, fn -> %{} end)

    # The intrinsic width/height attributes give the default size and lose to
    # any `w-*` / `h-*` class (CSS beats SVG presentation attributes). The body
    # is trusted path markup read from priv at compile time, so `raw/1` is safe.
    ~H"""
    <svg
      class={@class}
      style={@style}
      width={@icon.size}
      height={@icon.size}
      {@icon.attrs}
      aria-hidden="true"
      xmlns="http://www.w3.org/2000/svg"
      {@rest}
    >{Phoenix.HTML.raw(@icon.body)}</svg>
    """
  end

  @doc "The empty placeholder drawn for a name no icon set knows."
  @spec unknown(map()) :: Phoenix.LiveView.Rendered.t()
  def unknown(assigns) do
    ~H"""
    <span class={@class} style={@style} />
    """
  end

  @spec fetch(String.t()) :: {:ok, IconSource.icon()} | :error
  defp fetch(name) when is_binary(name) do
    if String.starts_with?(name, "hero-"),
      do: Heroicons.fetch(name),
      else: CustomIcons.fetch(name)
  end

  defp fetch(_name), do: :error
end
