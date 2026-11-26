defmodule Tymeslot.Security.BreachedPasswords.Offline do
  @moduledoc """
  Lookup used in tests. The local common-password list still applies; this
  module adds nothing and never opens a socket.
  """

  @doc "Always false. The caller already checked the local list."
  @spec breached?(String.t()) :: false
  def breached?(password) when is_binary(password), do: false
end
