defmodule Tymeslot.Plans.BillingClient.HTTP do
  @moduledoc """
  growth-os-billing client. Bearer auth is the BookDesk24 path. The API key
  stays in the server environment. This module does not set Stripe tax.
  """

  @behaviour Tymeslot.Plans.BillingClient

  alias Tymeslot.Infrastructure.HTTPClient
  alias Tymeslot.Plans
  alias Tymeslot.Plans.ReturnUrls

  @impl Tymeslot.Plans.BillingClient
  def create_checkout(user, interval, urls) do
    body =
      %{
        "product" => "booking",
        "price_lookup_key" => lookup_key(interval),
        "external_user_id" => Plans.external_user_id(user_id(user)),
        "email" => field(user, :email),
        "locale" => locale(user),
        "success_url" => success_url(urls),
        "cancel_url" => cancel_url(urls)
      }

    session_result(post("/v1/checkout-sessions", body))
  end

  @impl Tymeslot.Plans.BillingClient
  def create_portal(user, return_url) do
    session_result(
      post("/v1/portal-sessions", %{
        "product" => "booking",
        "external_user_id" => Plans.external_user_id(user_id(user)),
        "return_url" => portal_return_url(return_url)
      })
    )
  end

  @impl Tymeslot.Plans.BillingClient
  def get_entitlement(user_id) do
    query =
      URI.encode_query(%{
        "product" => "booking",
        "external_user_id" => Plans.external_user_id(user_id)
      })

    case request(:get, "/v1/entitlements?" <> query, "") do
      {:ok, body} -> {:ok, body}
      {:error, {:http, 404}} -> {:error, :not_found}
      other -> other
    end
  end

  @impl Tymeslot.Plans.BillingClient
  def register_account(user) do
    body =
      %{"product" => "booking", "external_user_id" => Plans.external_user_id(user_id(user))}
      |> Map.put("email", field(user, :email))
      |> Map.put("locale", locale(user))
      |> Map.put("trial", true)
      |> put_present("name", field(user, :name))
      |> put_present("organisation_id", organisation_id(user))

    case post("/v1/accounts", body) do
      {:ok, response} -> {:ok, response}
      {:error, {:http, 409}} -> :ok
      other -> other
    end
  end

  @impl Tymeslot.Plans.BillingClient
  def cancel(user_id, opts) do
    external = Plans.external_user_id(user_id)

    body = %{
      "product" => "booking",
      "reason" => opt(opts, :reason, "account_deleted"),
      "at_period_end" => opt(opts, :at_period_end, false)
    }

    case post("/v1/accounts/" <> external <> "/cancel", body) do
      {:ok, _response} -> :ok
      {:error, {:http, 404}} -> :ok
      other -> other
    end
  end

  @doc "GET `{base}/healthz`. `:ok` only when the service answers 2xx."
  @spec health() :: :ok | {:error, term()}
  def health do
    with {:ok, base, _key} <- credentials() do
      url = String.trim_trailing(base, "/") <> "/healthz"

      case http().request(:get, url, "", [{"accept", "application/json"}], timeout_opts()) do
        {:ok, %{status: status}} when status in 200..299 -> :ok
        {:ok, %{status: status}} -> {:error, {:http, status}}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp lookup_key(interval) when interval in ["year", "yearly"], do: "booking_pro_yearly"
  defp lookup_key(_interval), do: "booking_pro_monthly"

  defp success_url(urls) do
    value = url_param(urls, :success)
    if ReturnUrls.https?(value), do: value, else: ReturnUrls.checkout().success
  end

  defp cancel_url(urls) do
    value = url_param(urls, :cancel)

    if ReturnUrls.https?(value) and not String.contains?(value, "?") do
      value
    else
      ReturnUrls.checkout().cancel
    end
  end

  defp portal_return_url(url) do
    if ReturnUrls.https?(url), do: url, else: ReturnUrls.portal()
  end

  defp url_param(urls, key) when is_map(urls) do
    case Map.fetch(urls, key) do
      {:ok, value} -> value
      :error -> Map.get(urls, Atom.to_string(key))
    end
  end

  defp url_param(_urls, _key), do: nil

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
          :get -> http().request(:get, url, "", headers, timeout_opts())
          :post -> http().request(:post, url, body, headers, timeout_opts())
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

  defp timeout_opts, do: [timeout: 5_000, receive_timeout: 5_000]

  defp http do
    Application.get_env(:tymeslot, :http_client_module, HTTPClient)
  end

  defp session_result({:ok, body}) when is_map(body) do
    url = field(body, :url)
    mode = field(body, :mode)

    cond do
      is_binary(url) and url != "" and is_binary(mode) ->
        {:ok, %{url: url, mode: mode}}

      is_binary(url) and url != "" ->
        {:ok, %{url: url}}

      mode == "noop" ->
        {:ok, %{mode: "noop"}}

      true ->
        {:error, :missing_url}
    end
  end

  defp session_result(other), do: other

  defp decode(body) when is_map(body), do: body

  defp decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, map} -> map
      _invalid -> %{}
    end
  end

  defp decode(_body), do: %{}

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

  defp user_id(user) do
    case field(user, :id) do
      id when is_integer(id) and id > 0 ->
        id

      id when is_binary(id) ->
        case Integer.parse(id) do
          {parsed, ""} when parsed > 0 -> parsed
          _invalid -> 0
        end

      _missing ->
        0
    end
  end

  defp locale(user) do
    raw = user |> field(:locale) |> to_string()
    if String.starts_with?(raw, "de"), do: "de", else: "en"
  end

  defp organisation_id(user) do
    field(user, :organisation_id) || field(user, :organization_id)
  end

  defp field(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp field(_map, _key), do: nil

  defp put_present(map, _key, value) when value in [nil, ""], do: map
  defp put_present(map, key, value) when is_binary(value), do: Map.put(map, key, value)
  defp put_present(map, _key, _value), do: map

  defp opt(opts, key, default) when is_list(opts), do: Keyword.get(opts, key, default)

  defp opt(opts, key, default) when is_map(opts) do
    cond do
      Map.has_key?(opts, key) -> Map.get(opts, key)
      Map.has_key?(opts, Atom.to_string(key)) -> Map.get(opts, Atom.to_string(key))
      true -> default
    end
  end

  defp opt(_opts, _key, default), do: default
end
