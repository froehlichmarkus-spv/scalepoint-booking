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

  # Lucide names for the shell and auth. Anything else stays a Heroicon.
  defp lucide_id("hero-x-mark"), do: "i-x"
  defp lucide_id("hero-arrow-top-right-on-square"), do: "i-external-link"
  defp lucide_id("hero-clipboard"), do: "i-copy"
  defp lucide_id("hero-chevron-double-right"), do: "i-chevron-right"
  defp lucide_id("hero-chevron-double-left"), do: "i-chevron-left"
  defp lucide_id("hero-home"), do: "i-layout-dashboard"
  defp lucide_id("hero-calendar-days"), do: "i-calendar"
  defp lucide_id("hero-clock"), do: "i-clock"
  defp lucide_id("hero-chart-bar"), do: "i-chart-column"
  defp lucide_id("hero-squares-2x2"), do: "i-layout-dashboard"
  defp lucide_id("hero-map-pin"), do: "i-map-pin"
  defp lucide_id("hero-adjustments-horizontal"), do: "i-sliders-horizontal"
  defp lucide_id("hero-hand-raised"), do: "i-users"
  defp lucide_id("hero-rectangle-stack"), do: "i-file-text"
  defp lucide_id("hero-language"), do: "i-globe"
  defp lucide_id("hero-puzzle-piece"), do: "i-link-2"
  defp lucide_id("hero-code-bracket"), do: "i-command"
  defp lucide_id("hero-user"), do: "i-user"
  defp lucide_id("hero-bolt"), do: "i-zap"
  defp lucide_id("hero-bars-3"), do: "i-menu"
  defp lucide_id("hero-envelope"), do: "i-mail"
  defp lucide_id("hero-lock-closed"), do: "i-lock"
  defp lucide_id("hero-arrow-left"), do: "i-arrow-left"
  defp lucide_id("hero-arrow-left-mini"), do: "i-arrow-left"
  defp lucide_id("hero-eye"), do: "i-eye"
  defp lucide_id("hero-eye-slash"), do: "i-eye-off"
  defp lucide_id("hero-arrow-path"), do: "i-refresh-cw"
  defp lucide_id("hero-exclamation-circle"), do: "i-circle-alert"
  defp lucide_id("hero-check"), do: "i-check"
  defp lucide_id(_name), do: nil

  attr :sprite_id, :string, required: true
  attr :class, :any, default: nil
  attr :style, :string, default: nil
  attr :rest, :global

  defp lucide(assigns) do
    ~H"""
    <svg class={["gos-icon", @class]} style={@style} aria-hidden="true" {@rest}>
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
