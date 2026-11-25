defmodule TymeslotWeb.Branding.PoweredBy do
  @moduledoc """
  Fixed "Powered by BookDesk24" badge for Free booking pages.

  Rendered through `:theme_extensions`, so every theme and the embed get it.
  It sits fixed on the viewport, outside the theme's custom CSS container.
  Pro does not show it. A host previewing their own page sees a note instead
  of the public badge.
  """

  use Phoenix.Component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Brands
  alias Tymeslot.Payments

  @spec badge(map()) :: Phoenix.LiveView.Rendered.t()
  def badge(assigns) do
    organizer_id = assigns[:organizer_user_id]
    preview = assigns[:owner_preview] == true
    show = assigns[:should_show_branding] == true and not preview
    hint = preview and is_integer(organizer_id) and Payments.show_branding?(organizer_id)

    assigns =
      assigns
      |> assign(:show, show)
      |> assign(:hint, hint)
      |> assign(:product, Brands.product_name())
      |> assign(:href, System.get_env("POWERED_BY_URL") || Brands.footer_href())

    ~H"""
    <a
      :if={@show}
      class="gos-powered-by"
      href={@href}
      rel="noopener noreferrer"
      data-testid="powered-by-bookdesk24"
    >
      {dgettext("plans", "Powered by")} <strong>{@product}</strong>
    </a>
    <p :if={@hint} class="gos-powered-by" data-testid="powered-by-preview">
      {dgettext("plans", "Visible on Free: Powered by %{product}", product: @product)}
    </p>
    """
  end
end
