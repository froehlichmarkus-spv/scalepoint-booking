defmodule Tymeslot.Plans.ReturnUrls do
  @moduledoc """
  HTTPS return addresses growth-os-billing accepts for BookDesk24.

  Checkout's success page is `/welcome`. The cancel address has no query
  string, so billing can append `?billing=payment_failed` when a pro-rata
  charge fails.
  """

  @public_base "https://book.scalepoint-ventures.com"

  @spec checkout() :: %{success: String.t(), cancel: String.t()}
  def checkout do
    base = public_base()
    %{success: base <> "/welcome", cancel: base <> "/dashboard/plan"}
  end

  @spec portal() :: String.t()
  def portal, do: public_base() <> "/dashboard/plan"

  @spec https?(term()) :: boolean()
  def https?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: "https", host: host} when is_binary(host) and host != "" -> true
      _other -> false
    end
  end

  def https?(_url), do: false

  defp public_base do
    configured =
      :tymeslot
      |> Application.get_env(:plans, [])
      |> Keyword.get(:public_base_url)

    if is_binary(configured) and configured != "" do
      String.trim_trailing(configured, "/")
    else
      @public_base
    end
  end
end
