defmodule Tymeslot.Emails.Shared.LinkLifetime do
  @moduledoc """
  How long an emailed auth link stays valid, in the reader's language.

  Every length is `Tymeslot.Auth.AccountTokens.ttl_seconds/1`: 30 minutes for
  verification, 60 for a password reset, 15 for a magic link. This module
  does not keep a second number.
  """

  alias Tymeslot.Auth.AccountTokens

  use Gettext, backend: TymeslotWeb.Gettext

  @type kind :: :verification | :reset | :magic_link

  @doc "Lifetime of `kind`, in seconds, from the token that the link carries."
  @spec seconds(kind()) :: pos_integer()
  def seconds(kind), do: AccountTokens.ttl_seconds(kind)

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
