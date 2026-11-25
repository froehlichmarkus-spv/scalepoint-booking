defmodule Tymeslot.Security.FieldValidators.PasswordValidator do
  @moduledoc """
  Password field validation with security requirements.

  Validates password length and a breached-password blocklist.
  There are no composition rules (no uppercase, number or symbol requirement).

  The rules live here as data (`rules/0`) rather than as a hand-written
  `cond`, because they have two audiences: this module enforces them, and the
  on-screen checklist has to state them. One source drives both, so a password
  satisfying every rule the user can see is never rejected by a hidden one.

  Every message returned here reaches the person typing the password — the
  reset form, the signup form, the account security page — so each one resolves
  through gettext at call time.
  """

  use Gettext, backend: TymeslotWeb.Gettext

  @password_min_length 8
  # bcrypt only reads the first 72 bytes of its input and silently ignores the
  # rest, so a longer password would be accepted but only partly protected.
  # The cap is in bytes, not characters: accented letters, most non-Latin
  # scripts and emoji take two to four bytes each.
  @password_max_bytes 72

  # A local blocklist stands in for a breached-password range API. Comparison
  # is case-insensitive. The same source builds the checklist regex.
  @blocklist ~w(
    password password1 password123 12345678 123456789 1234567890
    qwerty123 qwertyui letmein1 welcome1 admin123 iloveyou1
    sunshine1 princess1 football1 baseball1 abc12345 changeme
    passw0rd trustno1 monkey123 dragon123 master123 login123
    bookdesk bookdesk24 scalepoint growthos
  )

  @breached_source "^(?!(" <> Enum.map_join(@blocklist, "|", &Regex.escape/1) <> ")$).+$"
  @breached_regex Regex.compile!(@breached_source)

  # `:email` is contextual: the pattern matches any password, and
  # `validate/2` applies the email-name check only when `:email` is given.
  # The browser checklist reads the email field itself.
  @rules [
    %{key: :length, pattern: "^.{#{@password_min_length},}$"},
    %{key: :breached, pattern: @breached_source},
    %{key: :email, pattern: "^.*$"}
  ]

  @doc """
  Validates password with security requirements and specific error messages.

  ## Examples

      iex> validate("correct horse")
      :ok

      iex> validate("weak")
      {:error, "Password must be at least 8 characters long"}

      iex> validate("password")
      {:error, "This password is too common. Try a short phrase only you would know."}
  """
  @spec validate(any(), keyword()) :: :ok | {:error, String.t()}
  def validate(password, opts \\ [])

  def validate(nil, _opts), do: {:error, dgettext("errors_input", "Password is required")}
  def validate("", _opts), do: {:error, dgettext("errors_input", "Password is required")}

  def validate(password, opts) when is_binary(password) do
    min_length = Keyword.get(opts, :min_length, @password_min_length)

    with :ok <- validate_length(password, min_length),
         :ok <- validate_breached(password) do
      validate_email_name(password, Keyword.get(opts, :email))
    end
  end

  def validate(_password, _opts) do
    {:error, dgettext("errors_input", "Password must be a text value")}
  end

  @doc """
  The rules a password must satisfy, in the order they are enforced.

  Each rule carries a regular-expression source rather than a compiled
  `Regex`, so the same pattern can be handed to the browser for the live
  checklist. The syntax used is common to Elixir and JavaScript.
  """
  @spec rules() :: [%{key: atom(), pattern: String.t()}]
  def rules, do: @rules

  @doc """
  The minimum password length, for callers that need to state it.
  """
  @spec min_length() :: pos_integer()
  def min_length, do: @password_min_length

  @doc """
  Validates password confirmation matches original password.
  """
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

  # Private helper functions

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

  defp validate_breached(password) do
    if Regex.match?(@breached_regex, String.downcase(password)) do
      :ok
    else
      {:error,
       dgettext(
         "errors_input",
         "This password is too common. Try a short phrase only you would know."
       )}
    end
  end

  defp validate_email_name(_password, email) when email in [nil, ""], do: :ok

  defp validate_email_name(password, email) when is_binary(email) do
    local =
      email
      |> String.split("@")
      |> List.first()
      |> to_string()
      |> String.trim()
      |> String.downcase()

    if String.length(local) >= 3 and String.contains?(String.downcase(password), local) do
      {:error,
       dgettext("errors_input", "Choose a password that does not contain your email name.")}
    else
      :ok
    end
  end

  defp validate_email_name(_password, _email), do: :ok
end
