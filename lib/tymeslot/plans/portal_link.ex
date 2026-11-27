defmodule Tymeslot.Plans.PortalLink do
  @moduledoc """
  Signed `GET /portal` link. The webhook secret never leaves the server.

  Billing checks `HMAC-SHA256(secret, "portal." + module + "." + account + "." + exp)`
  and opens a fresh Customer Portal session. The link lives at most 14 days;
  the default is 7.
  """

  @default_ttl 7 * 86_400
  @max_ttl 14 * 86_400
  @modules ~w(booking connect outreach crm)
  @default_base "https://billing.scalepoint-ventures.com"

  @spec sign(String.t(), String.t(), integer(), String.t()) :: String.t()
  def sign(module, account_id, exp, secret)
      when is_binary(module) and is_binary(account_id) and is_integer(exp) and is_binary(secret) do
    payload = "portal." <> module <> "." <> account_id <> "." <> Integer.to_string(exp)
    mac = :crypto.mac(:hmac, :sha256, secret, payload)
    Base.encode16(mac, case: :lower)
  end

  @spec build(String.t(), keyword()) ::
          {:ok, String.t()} | {:error, :not_configured | :invalid_module}
  def build(account_id, opts \\ []) when is_binary(account_id) and account_id != "" do
    module = Keyword.get(opts, :module, "booking")

    with true <- module in @modules,
         {:ok, secret} <- secret(opts) do
      exp = expiry(opts)
      sig = sign(module, account_id, exp, secret)
      {:ok, base(opts) <> "/portal?" <> query(account_id, module, exp, sig)}
    else
      false -> {:error, :invalid_module}
      {:error, :not_configured} = error -> error
    end
  end

  defp query(account_id, module, exp, sig) do
    "a=" <>
      URI.encode_www_form(account_id) <>
      "&m=" <>
      URI.encode_www_form(module) <>
      "&exp=" <>
      Integer.to_string(exp) <>
      "&sig=" <>
      sig
  end

  defp secret(opts) do
    case Keyword.get(opts, :secret) do
      value when is_binary(value) and value != "" ->
        {:ok, value}

      _missing ->
        configured =
          :tymeslot
          |> Application.get_env(:plans, [])
          |> Keyword.get(:webhook_secret)

        if is_binary(configured) and configured != "" do
          {:ok, configured}
        else
          {:error, :not_configured}
        end
    end
  end

  defp base(opts) do
    case Keyword.get(opts, :base) do
      value when is_binary(value) and value != "" ->
        String.trim_trailing(value, "/")

      _missing ->
        configured =
          :tymeslot
          |> Application.get_env(:plans, [])
          |> Keyword.get(:billing_url)

        if is_binary(configured) and configured != "" do
          String.trim_trailing(configured, "/")
        else
          @default_base
        end
    end
  end

  defp expiry(opts) do
    case Keyword.get(opts, :exp) do
      exp when is_integer(exp) and exp > 0 ->
        exp

      _missing ->
        System.system_time(:second) + clamp_ttl(Keyword.get(opts, :ttl, @default_ttl))
    end
  end

  defp clamp_ttl(ttl) when is_integer(ttl) and ttl > 0 and ttl <= @max_ttl, do: ttl
  defp clamp_ttl(ttl) when is_integer(ttl) and ttl > @max_ttl, do: @max_ttl
  defp clamp_ttl(_ttl), do: @default_ttl
end
