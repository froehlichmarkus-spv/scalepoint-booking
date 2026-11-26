defmodule Tymeslot.Licensing.SourceOffer do
  @moduledoc """
  Corresponding source for the AGPLv3 offer.

  `SOURCE_OFFER_URL` overrides the address. An empty value hides the link.
  When the variable is unset outside the test environment, the public
  repository is used.
  """

  @default "https://github.com/froehlichmarkus-spv/scalepoint-booking"

  @spec default_url() :: String.t()
  def default_url, do: @default

  @spec url() :: String.t() | nil
  def url do
    case Application.get_env(:tymeslot, :source_offer_url) do
      value when is_binary(value) and value != "" -> value
      _missing -> nil
    end
  end
end
