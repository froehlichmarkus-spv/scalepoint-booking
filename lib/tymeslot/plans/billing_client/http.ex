defmodule Tymeslot.Plans.BillingClient.HTTP do
  @moduledoc "Req-backed growth-os-billing client. Secrets stay in the server environment."

  @behaviour Tymeslot.Plans.BillingClient

  alias Tymeslot.Infrastructure.HTTPClient
  alias Tymeslot.Plans

  @impl true
  def create_checkout(user, interval, urls) do
    post("/v1/checkout-sessions", %{
      "product" => "booking",
      "price_lookup_key" => lookup_key(interval),
      "external_user_id" => Plans.external_user_id(user.id),
      "email" => user.email,
      "success_url" => urls[:success] || urls["success"],
      "cancel_url" => urls[:cancel] || urls["cancel"]
    })
    |> url_result()
  end

  @impl true
  def create_portal(user, return_url) do
    post("/v1/portal-sessions", %{
      "product" => "booking",
      "external_user_id" => Plans.external_user_id(user.id),
      "return_url" => return_url
    })
    |> url_result()
  end

  @impl true
  def get_entitlement(user_id) do
    query =
      URI.encode_query(%{
        "product" => "booking",
        "external_user_id" => Plans.external_user_id(user_id)
      })

    case request(:get, "/v1/entitlements?" <> query, "") do
      {:ok, body} -> {:ok, body}
      other -> other
    end
  end

  @impl true
  def register_account(user) do
    case post("/v1/accounts", %{
           "product" => "booking",
           "external_user_id" => Plans.external_user_id(user.id),
           "email" => user.email,
           "name" => Map.get(user, :name),
           "trial" => true
         }) do
      {:ok, _} -> :ok
      other -> other
    end
  end

  @impl true
  def cancel(user_id, opts) do
    external = Plans.external_user_id(user_id) |> URI.encode_www_form()
    at_period_end = Keyword.get(List.wrap(opts), :at_period_end, false)
    reason = Keyword.get(List.wrap(opts), :reason, "account_deleted")

    case post("/v1/accounts/" <> external <> "/cancel", %{
           "reason" => reason,
           "at_period_end" => at_period_end
         }) do
      {:ok, _} -> :ok
      {:error, {:http, 404}} -> :ok
      other -> other
    end
  end

  defp lookup_key("year"), do: "booking_pro_yearly"
  defp lookup_key(_), do: "booking_pro_monthly"

  defp post(path, body), do: request(:post, path, Jason.encode!(body))

  defp request(method, path, body) do
    with {:ok, base, key} <- credentials() do
      headers = [
        {"authorization", "Bearer " <> key},
        {"content-type", "application/json"},
        {"accept", "application/json"}
      ]

      url = String.trim_trailing(base, "/") <> path

      result =
        case method do
          :get -> HTTPClient.get(url, headers)
          :post -> HTTPClient.post(url, body, headers)
        end

      case result do
        {:ok, %{status: status, body: response}} when status in 200..299 ->
          {:ok, decode(response)}

        {:ok, %{status: status}} ->
          {:error, {:http, status}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp url_result({:ok, %{"url" => url}}) when is_binary(url), do: {:ok, %{url: url}}
  defp url_result({:ok, %{url: url}}) when is_binary(url), do: {:ok, %{url: url}}
  defp url_result({:ok, _}), do: {:error, :missing_url}
  defp url_result(other), do: other

  defp decode(body) when is_map(body), do: body

  defp decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> map
      _ -> %{}
    end
  end

  defp decode(_), do: %{}

  defp credentials do
    plans = Application.get_env(:tymeslot, :plans, [])
    base = Keyword.get(plans, :billing_url)
    key = Keyword.get(plans, :billing_api_key)

    if is_binary(base) and base != "" and is_binary(key) and key != "" do
      {:ok, base, key}
    else
      {:error, :not_configured}
    end
  end
end
