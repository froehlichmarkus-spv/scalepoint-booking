defmodule TymeslotWeb.Components.CoreComponents.Brand do
  @moduledoc "Brand-related components (logos, marks) extracted from CoreComponents."
  use Phoenix.Component
  use Gettext, backend: TymeslotWeb.Gettext

  @doc """
  Renders the Tymeslot logo.

  ## Attributes
    * `mode` - Either :full (logo + text) or :icon (logo only). Defaults to :full.
    * `class` - Additional CSS classes for the container.
    * `img_class` - Additional CSS classes for the image element.
  """
  attr :mode, :atom, default: :full, values: [:full, :icon]
  attr :class, :string, default: nil
  attr :img_class, :string, default: "h-10"

  @spec logo(map()) :: Phoenix.LiveView.Rendered.t()
  def logo(assigns) do
    name = Tymeslot.Brands.product_name()
    {head, accent} = wordmark(name)

    assigns =
      assigns
      |> assign(:head, head)
      |> assign(:accent, accent)
      |> assign(:byline, Tymeslot.Brands.byline())
      |> assign(:suite, Tymeslot.Brands.suite_title())
      |> assign(:show_suite, Tymeslot.Brands.suite_title() != name)

    ~H"""
    <div class={["flex items-center gap-3", @class]}>
      <img
        src={Tymeslot.Brands.chrome_logo()}
        alt={Tymeslot.Brands.product_name()}
        class={[@img_class, "w-auto", @mode == :icon && "h-8"]}
      />
      <div :if={@mode == :full} class="min-w-0">
        <div class="gos-wordmark">
          {@head}<span :if={@accent} class="gos-wordmark-accent">{@accent}</span>
        </div>
        <div :if={@byline} class="gos-byline">{@byline}</div>
        <div :if={@show_suite} class="gos-suite-line">{@suite}</div>
      </div>
    </div>
    """
  end

  defp wordmark(name) do
    case String.split(name, "24", parts: 2) do
      [head, _tail] when head != "" -> {head, "24"}
      _ -> {name, nil}
    end
  end
end
