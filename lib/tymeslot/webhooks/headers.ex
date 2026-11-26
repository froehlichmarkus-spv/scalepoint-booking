defmodule Tymeslot.Webhooks.Headers do
  @moduledoc """
  Names of the headers on an outgoing webhook.

  Current requests use the `X-BookDesk24-` prefix and the user agent
  `BookDesk24-Webhooks/1.0`. Older deliveries used `X-Tymeslot-` and, for a
  short time, `X-the scheduler-` or `X-the-scheduler-`. Those legacy names are
  no longer sent. A redirect to another origin still strips the token header
  under every known prefix, so a leftover legacy header cannot ride along.

  See `docs/qa/WEBHOOK-HEADERS.md`.
  """

  @current "X-BookDesk24"
  @legacy ["X-Tymeslot", "X-the scheduler", "X-the-scheduler"]

  @doc "Header carrying the shared webhook token."
  @spec token() :: String.t()
  def token, do: @current <> "-Token"

  @doc "Header carrying `t=<unix>,v1=<hex hmac>`."
  @spec signature() :: String.t()
  def signature, do: @current <> "-Signature"

  @doc "Header carrying the signature timestamp as ISO-8601."
  @spec timestamp() :: String.t()
  def timestamp, do: @current <> "-Timestamp"

  @doc "Header carrying the stable delivery id."
  @spec delivery_id() :: String.t()
  def delivery_id, do: @current <> "-Delivery-Id"

  @doc "User agent on outgoing webhook posts."
  @spec user_agent() :: String.t()
  def user_agent, do: "BookDesk24-Webhooks/1.0"

  @doc """
  Whether `name` is a webhook token header, current or legacy.

  Comparison is case-insensitive. Used when a redirect must not forward the
  token to another origin.
  """
  @spec sensitive_token?(String.t()) :: boolean()
  def sensitive_token?(name) when is_binary(name) do
    down = String.downcase(name)

    Enum.any?([@current | @legacy], fn prefix ->
      String.starts_with?(down, String.downcase(prefix) <> "-token")
    end)
  end
end
