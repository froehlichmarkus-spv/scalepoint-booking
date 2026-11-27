defmodule Tymeslot.Mailer.Identity do
  @moduledoc """
  Platform sender and reply address for transactional mail.

  `MAIL_FROM` is `Name <email>` or a bare address. When it is unset,
  `EMAIL_FROM_ADDRESS` and `EMAIL_FROM_NAME` still apply, so a server that
  has not set `MAIL_FROM` keeps its current sender. When those are unset
  too, the suite defaults apply:

    * From: BookDesk24 <noreply@scalepoint-ventures.com>
    * Reply-To: support@scalepoint-ventures.com

  A tenant from-name is applied later by
  `Tymeslot.Emails.Shared.MjmlEmail.fetch_from_name/0`. This module only
  reads the platform identity.
  """

  @default_from_email "noreply@scalepoint-ventures.com"
  @default_from_name "BookDesk24"
  @default_reply_to "support@scalepoint-ventures.com"

  @type t :: %{from_name: String.t(), from_email: String.t(), reply_to: String.t()}

  @doc """
  Resolves the platform identity.

  `getenv` defaults to `System.get_env/1` and is injected in tests so the
  function does not depend on the process environment.
  """
  @spec resolve((String.t() -> String.t() | nil)) :: t()
  def resolve(getenv \\ &System.get_env/1) when is_function(getenv, 1) do
    reply_to =
      present(getenv, "MAIL_REPLY_TO") ||
        present(getenv, "EMAIL_SUPPORT_ADDRESS") ||
        @default_reply_to

    case present(getenv, "MAIL_FROM") do
      nil ->
        %{
          from_name:
            present(getenv, "EMAIL_FROM_NAME") || cloudron_name(getenv) || @default_from_name,
          from_email:
            present(getenv, "EMAIL_FROM_ADDRESS") ||
              present(getenv, "CLOUDRON_MAIL_FROM") ||
              @default_from_email,
          reply_to: reply_to
        }

      mail_from ->
        {name, email} = parse_from(mail_from)

        %{
          from_name: name || present(getenv, "EMAIL_FROM_NAME") || @default_from_name,
          from_email: email,
          reply_to: reply_to
        }
    end
  end

  @spec default_from_email() :: String.t()
  def default_from_email, do: @default_from_email

  @spec default_from_name() :: String.t()
  def default_from_name, do: @default_from_name

  @spec default_reply_to() :: String.t()
  def default_reply_to, do: @default_reply_to

  defp cloudron_name(getenv) do
    if present(getenv, "CLOUDRON_MAIL_FROM"), do: @default_from_name
  end

  defp present(getenv, var) do
    case getenv.(var) do
      value when is_binary(value) ->
        case String.trim(value) do
          "" -> nil
          trimmed -> trimmed
        end

      _other ->
        nil
    end
  end

  # "BookDesk24 <noreply@scalepoint-ventures.com>" or a bare address.
  defp parse_from(value) do
    case Regex.run(~r/\A(?<name>.*?)\s*<(?<email>[^<>]+)>\s*\z/, value) do
      [_all, name, email] ->
        name = String.trim(name)
        {if(name == "", do: nil, else: name), String.trim(email)}

      _other ->
        {nil, String.trim(value)}
    end
  end
end
