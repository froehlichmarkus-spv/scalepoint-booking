defmodule TymeslotWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.
  """
  use TymeslotWeb, :html
  use Gettext, backend: TymeslotWeb.Gettext

  alias Phoenix.Controller
  alias Tymeslot.Brands

  @doc "Product name for the branded error pages."
  @spec product_name() :: String.t()
  def product_name, do: Brands.product_name()

  @doc "Home link on the error pages."
  @spec home_label() :: String.t()
  def home_label, do: dgettext("errors", "Go to %{product}", product: product_name())

  @doc "Support address shown on the branded error pages."
  @spec support_email() :: String.t()
  def support_email do
    email = Application.get_env(:tymeslot, :email, [])
    email[:support_email] || "support@scalepoint-ventures.com"
  end

  # Branded, self-contained 404 and 500 pages live in `error_html/*.html.heex`
  # and are picked up by `embed_templates`. Every other status falls through
  # to the plain-text clause below.
  embed_templates "error_html/*"

  # The default is to render a plain text page based on
  # the template name. For example, "500.html" becomes
  # "Internal Server Error".
  @spec render(String.t(), map()) :: Phoenix.LiveView.Rendered.t() | String.t()
  def render(template, _assigns) do
    Controller.status_message_from_template(template)
  end
end
