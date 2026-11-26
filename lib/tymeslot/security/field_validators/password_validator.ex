defmodule Tymeslot.Security.FieldValidators.PasswordValidator do
  @moduledoc """
  Password field validation.

  The rules are a minimum of 8 characters, a maximum of 72 bytes, and a
  rejection of passwords that already appear in known data breaches. There is
  no composition rule: a passphrase of ordinary words is fine when it is long
  enough and not already breached.

  bcrypt only reads the first 72 bytes and would silently ignore the rest, so
  anything longer is refused with a message that says so. The cap is in bytes,
  not characters.

  `rules/0` is what the on-screen checklist renders. The breach check has no
  pattern a browser can evaluate, so it is enforced here and explained when it
  fails.
  """

  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Security.BreachedPasswords

  @password_min_length 8
  @password_max_bytes 72

  @rules [
    %{key: :length, pattern: "^.{#{@password_min_length},}$"},
    %{
      key: :max_bytes,
      pattern: "^[\\s\\S]{0,#{@password_max_bytes}}$",
      max_bytes: @password_max_bytes
    }
  ]

  @doc """
  Validates a password.

  ## Examples

      iex> validate("a long enough passphrase")
      :ok

      iex> validate("short")
      {:error, "Password must be at least 8 characters long"}
  """
  @spec validate(any(), keyword()) :: :ok | {:error, String.t()}
  def validate(password, opts \\ [])

  def validate(nil, _opts), do: {:error, dgettext("errors_input", "Password is required")}
  def validate("", _opts), do: {:error, dgettext("errors_input", "Password is required")}

  def validate(password, opts) when is_binary(password) do
    min_length = Keyword.get(opts, :min_length, @password_min_length)

    with :ok <- validate_length(password, min_length) do
      validate_not_breached(password)
    end
  end

  def validate(_password, _opts) do
    {:error, dgettext("errors_input", "Password must be a text value")}
  end

  @doc """
  The rules a password must satisfy that the browser can check live.

  Each rule carries a regular-expression source. `:max_bytes` also carries
  `max_bytes`, which the browser measures with `TextEncoder` because a
  character-count pattern understates letters that take more than one byte.
  """
  @spec rules() :: [%{optional(:max_bytes) => pos_integer(), key: atom(), pattern: String.t()}]
  def rules, do: @rules

  @doc "The minimum password length."
  @spec min_length() :: pos_integer()
  def min_length, do: @password_min_length

  @doc "The maximum password length in bytes, matching bcrypt's input."
  @spec max_bytes() :: pos_integer()
  def max_bytes, do: @password_max_bytes

  @doc "Whether the confirmation matches the password."
  @spec validate_confirmation(String.t(), String.t()) :: :ok | {:error, String.t()}
  def validate_confirmation(password, password) when is_binary(password) do
    :ok
  end

  def validate_confirmation(_password, nil) do
    {:error, dgettext("errors_input", "Password confirmation is required")}
  end

  def validate_confirmation(_password, "") do
    {:error, dgettext("errors_input", "Password confirmation is required")}
  end

  def validate_confirmation(_password, _confirmation) do
    {:error, dgettext("errors_input", "Password confirmation does not match")}
  end

  defp validate_length(password, min_length) do
    cond do
      String.length(password) < min_length ->
        {:error,
         dngettext(
           "errors_input",
           "Password must be at least %{count} character long",
           "Password must be at least %{count} characters long",
           min_length
         )}

      byte_size(password) > @password_max_bytes ->
        {:error,
         dgettext(
           "errors_input",
           "Password must be at most %{count} bytes long. Accented letters and emoji count as more than one byte.",
           count: @password_max_bytes
         )}

      true ->
        :ok
    end
  end

  defp validate_not_breached(password) do
    # Keeps the previous composition msgids in the extract, which stays on main.
    _catalog =
      [
        dgettext_noop("errors_input", "Password must contain at least one lowercase letter"),
        dgettext_noop("errors_input", "Password must contain at least one uppercase letter"),
        dgettext_noop("errors_input", "Password must contain at least one number"),
        dgettext_noop("errors_input", "Password must contain at least one special character")
      ]

    if BreachedPasswords.breached?(password) do
      {:error, "This password has appeared in a data breach. Choose a different one."}
    else
      :ok
    end
  end
end
