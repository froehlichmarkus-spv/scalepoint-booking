defmodule TymeslotWeb.Components.CoreComponents.Brand do
  @moduledoc "Brand-related components (logos, marks) extracted from CoreComponents."
  use Phoenix.Component
  use Gettext, backend: TymeslotWeb.Gettext

  @doc """
  Renders the BookDesk24 logo.

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

    ~H"""
    <div class={["flex items-center gap-3", @class]}>
      <img
        src="/images/brand/scalepoint-mark.svg"
        alt=""
        class={[@img_class, "w-auto", @mode == :icon && "h-8"]}
      />
      <div :if={@mode == :full} class="min-w-0">
        <div class="gos-wordmark">
          {@head}<span :if={@accent} class="gos-wordmark-accent">{@accent}</span>
        </div>
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
