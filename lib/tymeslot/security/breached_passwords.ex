defmodule Tymeslot.Security.BreachedPasswords do
  @moduledoc """
  Rejects passwords that are already known from data breaches.

  A built-in list always applies, including when the network is down. In
  deployed environments the Have I Been Pwned range API is asked as well
  (k-anonymity: only the first five characters of the SHA-1 hash leave the
  server). A lookup that fails does not block the password; the local list
  still does. Tests use `Offline`, which never calls the network.

  The password itself is never logged and never sent.
  """

  @external_resource Path.expand("../../../priv/security/common_passwords.txt", __DIR__)

  @common @external_resource
          |> File.read!()
          |> String.split(~r/\R/, trim: true)
          |> Enum.map(&String.downcase/1)
          |> MapSet.new()

  @doc "Whether `password` is on the local list or the configured lookup says so."
  @spec breached?(String.t()) :: boolean()
  def breached?(password) when is_binary(password) do
    local?(password) or lookup().breached?(password)
  end

  @doc "Whether the downcased password is in the shipped common-password list."
  @spec local?(String.t()) :: boolean()
  def local?(password) when is_binary(password) do
    MapSet.member?(@common, String.downcase(password))
  end

  @doc """
  Whether `suffix` (uppercase SHA-1 tail) appears in a HIBP range body with a
  count above zero. Padding rows use a count of zero and do not count.
  """
  @spec range_lists?(String.t(), String.t()) :: boolean()
  def range_lists?(body, suffix) when is_binary(body) and is_binary(suffix) do
    suffix = String.upcase(suffix)

    body
    |> String.split(~r/\R/, trim: true)
    |> Enum.any?(fn line ->
      case String.split(line, ":", parts: 2) do
        [hash, count] ->
          String.upcase(String.trim(hash)) == suffix and count_positive?(count)

        _other ->
          false
      end
    end)
  end

  defp count_positive?(count) do
    case Integer.parse(String.trim(count)) do
      {n, ""} -> n > 0
      _other -> false
    end
  end

  defp lookup do
    Application.get_env(:tymeslot, :breached_password_lookup, __MODULE__.Offline)
  end
end
