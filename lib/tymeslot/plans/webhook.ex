defmodule Tymeslot.Plans.Webhook do
  @moduledoc """
  Verifies `X-GOS-Signature: v1=<hex>` over `timestamp ++ "." ++ raw_body`.

  The tolerance is five minutes. Comparison uses `Plug.Crypto.secure_compare/2`.
  """

  alias Plug.Crypto
  alias Tymeslot.Plans

  @tolerance 300

  @spec verify(binary(), binary() | nil, binary() | nil) ::
          :ok | {:error, :invalid_signature | :not_configured}
  def verify(raw_body, timestamp, signature) when is_binary(raw_body) do
    with {:ok, secret} <- secret(),
         {:ok, ts} <- parse_timestamp(timestamp),
         true <- abs(System.system_time(:second) - ts) <= @tolerance,
         "v1=" <> hex <- signature,
         mac <- :crypto.mac(:hmac, :sha256, secret, "#{timestamp}.#{raw_body}"),
         expected <- Base.encode16(mac, case: :lower),
         true <-
           byte_size(hex) == byte_size(expected) and Crypto.secure_compare(hex, expected) do
      :ok
    else
      {:error, :not_configured} = error -> error
      _unused7 -> {:error, :invalid_signature}
    end
  end

  def verify(_unused14, _unused17, _unused20), do: {:error, :invalid_signature}

  @doc """
  Prefers `X-GOS-Timestamp` and `X-GOS-Signature`. Billing also sends
  `X-Growth-OS-Signature: t=<unix>,v1=<hex>` for the same body.
  """
  @spec signature_headers(binary() | nil, binary() | nil, binary() | nil) ::
          {binary() | nil, binary() | nil}
  def signature_headers(timestamp, signature, _combined)
      when is_binary(timestamp) and timestamp != "" and is_binary(signature) and signature != "" do
    {timestamp, signature}
  end

  def signature_headers(_timestamp, _signature, combined) when is_binary(combined) do
    parts =
      combined
      |> String.split(",", trim: true)
      |> Enum.reduce(%{}, fn part, acc ->
        case String.split(part, "=", parts: 2) do
          [key, value] -> Map.put(acc, key, value)
          _other -> acc
        end
      end)

    case {parts["t"], parts["v1"]} do
      {ts, hex} when is_binary(ts) and ts != "" and is_binary(hex) and hex != "" ->
        {ts, "v1=" <> hex}

      _missing ->
        {nil, nil}
    end
  end

  def signature_headers(_timestamp, _signature, _combined), do: {nil, nil}

  @spec process(binary()) :: {:ok, term()} | {:error, term()}
  def process(raw_body) do
    case Jason.decode(raw_body) do
      {:ok, payload} -> Plans.ingest_event(payload)
      _invalid -> {:error, :invalid_payload}
    end
  end

  defp secret do
    value = Keyword.get(Application.get_env(:tymeslot, :plans, []), :webhook_secret)

    if is_binary(value) and value != "" do
      {:ok, value}
    else
      {:error, :not_configured}
    end
  end

  defp parse_timestamp(ts) when is_binary(ts) do
    case Integer.parse(ts) do
      {n, ""} when n > 0 -> {:ok, n}
      _unused7 -> :error
    end
  end

  defp parse_timestamp(_unused24), do: :error
end
