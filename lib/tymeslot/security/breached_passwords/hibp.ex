defmodule Tymeslot.Security.BreachedPasswords.Hibp do
  @moduledoc """
  Have I Been Pwned range lookup.

  Sends the first five hex characters of `SHA1(password)` to
  `api.pwnedpasswords.com` and checks the suffix locally. `Add-Padding: true`
  asks the service to mix in dummy rows. A timeout or any other failure
  returns false so a signup is not blocked when the service is unreachable.
  """

  require Logger

  alias Tymeslot.Infrastructure.HTTPClient
  alias Tymeslot.Infrastructure.Logging.LogFormat
  alias Tymeslot.Security.BreachedPasswords

  @range_url "https://api.pwnedpasswords.com/range/"
  @timeout_ms 2_000

  @doc "Whether the exact password appears in the HIBP range response."
  @spec breached?(String.t()) :: boolean()
  def breached?(password) when is_binary(password) do
    hash = password |> then(&:crypto.hash(:sha, &1)) |> Base.encode16(case: :upper)
    {prefix, suffix} = String.split_at(hash, 5)

    case HTTPClient.get(
           @range_url <> prefix,
           [
             {"User-Agent", "BookDesk24-Password-Check"},
             {"Add-Padding", "true"}
           ],
           receive_timeout: @timeout_ms,
           max_response_bytes: 1_048_576
         ) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        BreachedPasswords.range_lists?(body, suffix)

      {:ok, response} ->
        Logger.warning("breached-password lookup returned an unexpected status",
          status: response.status
        )

        false

      {:error, reason} ->
        Logger.warning("breached-password lookup failed", reason: LogFormat.reason(reason))
        false
    end
  end
end
