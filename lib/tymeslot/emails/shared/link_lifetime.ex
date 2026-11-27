defmodule Tymeslot.Emails.Shared.LinkLifetime do
  @moduledoc """
  How long an emailed auth link stays valid, in the reader's language.

  Verification and password reset read `Tymeslot.Auth.AccountTokens.ttl_seconds/1`.
  That map is the one lifetime. PR #7 changes the seconds (DS v2.9 is 30
  minutes for verification and 60 for reset). This module must not carry a
  second number for those two.

  A magic-link token is not issued yet, so there is no attribute to read.
  TODO: when PR #7 adds that purpose, replace `@magic_link_seconds` with
  `AccountTokens.ttl_seconds(:magic_link)`. DS v2.9 is 15 minutes
  (`ds-v2.9-auth/booking/{en,de}/magic-link.html`).
  """

  alias Tymeslot.Auth.AccountTokens

  use Gettext, backend: TymeslotWeb.Gettext

  @magic_link_seconds 15 * 60

  @type kind :: :verification | :reset | :magic_link

  @doc "Lifetime of `kind`, in seconds, from the token that the link carries."
  @spec seconds(kind()) :: pos_integer()
  def seconds(:verification), do: AccountTokens.ttl_seconds(:verification)
  def seconds(:reset), do: AccountTokens.ttl_seconds(:reset)
  def seconds(:magic_link), do: @magic_link_seconds

  @doc "The lifetime as a phrase, for example 30 minutes or 30 Minuten."
  @spec duration(kind()) :: String.t()
  def duration(kind) do
    seconds = seconds(kind)

    cond do
      rem(seconds, 3600) == 0 and div(seconds, 3600) > 1 ->
        hours = div(seconds, 3600)
        dngettext("emails_account", "%{count} hour", "%{count} hours", hours, count: hours)

      rem(seconds, 60) == 0 ->
        minutes = div(seconds, 60)

        dngettext("emails_account", "%{count} minute", "%{count} minutes", minutes,
          count: minutes
        )

      true ->
        dngettext("emails_account", "%{count} second", "%{count} seconds", seconds,
          count: seconds
        )
    end
  end

  @doc "\"It works once, for 30 minutes.\" The duration is `duration/1`."
  @spec once(kind()) :: String.t()
  def once(kind) do
    dgettext("emails_account", "It works once, for %{duration}.", duration: duration(kind))
  end
end
