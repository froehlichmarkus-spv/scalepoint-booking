defmodule Tymeslot.Emails.SeedRecipients do
  @moduledoc """
  Addresses that must not receive mail.

  The neutral tenant has been a placeholder (`scheduler24.io`, then
  `meetdesk24.com`, now BookDesk24). Seeding used to register that owner
  through the normal sign-up path, which queues "Verify your email" before
  the account is marked verified. The job does not look at `verified_at`,
  so a later retry still delivers. `SEED_NEUTRAL_TENANT=false` only skips
  creating the account on a boot that already contains the guard. It does
  not cancel a job already in the queue, and it does not stop the worker.

  Retired domains are refused always. The owner and notify address of a
  disabled brand are refused too, and so are those of a non-house brand
  while `SEED_NEUTRAL_TENANT` is off. The house account is never in this
  list.
  """

  alias Tymeslot.Brands

  @retired_domains ~w(scheduler24.io meetdesk24.com)

  @doc "The blocked recipient on `email`, or nil when every recipient may be sent."
  @spec blocked_address(Swoosh.Email.t() | String.t()) :: String.t() | nil
  def blocked_address(%Swoosh.Email{} = email) do
    email
    |> addresses()
    |> Enum.find(&blocked?/1)
  end

  def blocked_address(address) when is_binary(address) do
    if blocked?(address), do: address, else: nil
  end

  @doc "Whether mail to `address` must be suppressed."
  @spec blocked?(String.t()) :: boolean()
  def blocked?(address) when is_binary(address) do
    normalised = normalise(address)
    domain = normalised |> String.split("@") |> List.last()
    domain in @retired_domains or normalised in blocked_addresses()
  end

  @doc "Every address currently suppressed, lowercased."
  @spec blocked_addresses() :: [String.t()]
  def blocked_addresses do
    Brands.documents()
    |> Enum.flat_map(&addresses_for/1)
    |> Enum.map(&normalise/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp addresses_for(%{enabled: false} = brand), do: mailbox(brand)

  defp addresses_for(%{house_brand: false} = brand) do
    if neutral_seed?(), do: [], else: mailbox(brand)
  end

  defp addresses_for(_brand), do: []

  defp mailbox(brand), do: [brand.owner_email, brand.notify_email, brand.sender_email]

  defp neutral_seed?, do: System.get_env("SEED_NEUTRAL_TENANT") in ["true", "1", "yes"]

  defp addresses(email) do
    [:to, :cc, :bcc]
    |> Enum.flat_map(&List.wrap(Map.get(email, &1)))
    |> Enum.map(fn
      {_name, address} -> address
      address when is_binary(address) -> address
      _other -> ""
    end)
  end

  defp normalise(address) when is_binary(address) do
    address |> String.trim() |> String.downcase()
  end

  defp normalise(_), do: ""
end
