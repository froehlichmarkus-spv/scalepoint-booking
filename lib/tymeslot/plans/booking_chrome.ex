defmodule Tymeslot.Plans.BookingChrome do
  @moduledoc """
  White-label pieces of a booking page.

  Pro keeps the host's uploaded logo and, when they chose an accent, rewrites
  `--spv-teal` and its strong/light pair on that page only. Free loses the
  custom logo. The dashboard never reads these overrides. A custom domain and
  mail from the customer's domain are Phase 2 and are not applied here.
  """

  alias Tymeslot.Plans
  alias Tymeslot.ThemeCustomizations.Presets.Accents
  alias Tymeslot.ThemeCustomizations.Tokens

  @doc "Tokens a public booking page may render for this host."
  @spec present(integer() | nil, map() | nil, Tokens.t()) :: Tokens.t()
  def present(user_id, customization, %Tokens{} = tokens) do
    cond do
      not Plans.enabled?() ->
        tokens

      not is_integer(user_id) or
          not Plans.feature?(Plans.effective_plan(user_id), :custom_logo_allowed) ->
        strip_logo(tokens)

      Plans.feature?(Plans.effective_plan(user_id), :custom_accent_allowed) ->
        put_accent(tokens, accent_hex(customization))

      true ->
        tokens
    end
  end

  def present(_user_id, _customization, tokens), do: tokens

  @doc "Pro may store a booking-page logo and accent. Turning a logo off is always allowed."
  @spec branding_change_allowed?(integer() | nil, atom(), term(), term()) :: boolean()
  def branding_change_allowed?(user_id, group, field, value) do
    plan = if is_integer(user_id), do: Plans.effective_plan(user_id), else: :free

    cond do
      not Plans.enabled?() -> true
      group == :logo and clearing_logo?(field, value) -> true
      group == :logo and not Plans.feature?(plan, :custom_logo_allowed) -> false
      group == :accent and not Plans.feature?(plan, :custom_accent_allowed) -> false
      true -> true
    end
  end

  @doc "Paints CTAs with a host accent. `nil` leaves the tokens alone."
  @spec apply_accent(Tokens.t(), String.t() | nil) :: Tokens.t()
  def apply_accent(%Tokens{} = tokens, hex) when is_binary(hex) do
    if valid_hex?(hex), do: put_accent(tokens, hex), else: tokens
  end

  def apply_accent(tokens, _), do: tokens

  defp strip_logo(%Tokens{media: media} = tokens) do
    %{tokens | media: Map.delete(media || %{}, :logo)}
  end

  defp put_accent(tokens, nil), do: tokens

  defp put_accent(%Tokens{vars: vars, dark_vars: dark} = tokens, hex) do
    strong = mix(hex, -0.18)

    override = %{
      "--spv-teal" => hex,
      "--spv-teal-strong" => strong,
      "--spv-teal-light" => mix(hex, 0.28),
      "--theme-primary" => hex,
      "--theme-primary-hover" => strong,
      "--theme-primary-solid" => hex,
      "--theme-primary-solid-hover" => strong,
      "--theme-accent" => hex,
      "--theme-accent-solid" => hex
    }

    %{tokens | vars: Map.merge(vars, override), dark_vars: Map.merge(dark, override)}
  end

  defp accent_hex(%{settings: settings}) when is_map(settings) do
    case settings["accent"] || settings[:accent] do
      "#" <> _ = hex -> if valid_hex?(hex), do: hex
      id when is_binary(id) -> Accents.all() |> get_in([id, :color])
      _ -> nil
    end
  end

  defp accent_hex(_), do: nil

  defp clearing_logo?(field, value) do
    field in ["logo_path", :logo_path] and value in [nil, ""]
  end

  defp valid_hex?(hex), do: Regex.match?(~r/\A#[0-9A-Fa-f]{6}\z/, hex)

  defp mix(hex, amount) do
    <<r, g, b>> = hex_bytes(hex)
    target = if amount < 0, do: 0, else: 255
    ratio = abs(amount)

    [r, g, b]
    |> Enum.map(fn channel ->
      round(channel + (target - channel) * ratio) |> min(255) |> max(0)
    end)
    |> then(fn [nr, ng, nb] ->
      "#" <>
        Enum.map_join([nr, ng, nb], "", &String.pad_leading(Integer.to_string(&1, 16), 2, "0"))
    end)
  end

  defp hex_bytes("#" <> rest) do
    rest =
      if String.length(rest) == 3,
        do:
          String.duplicate(String.first(rest), 2) <>
            String.duplicate(String.at(rest, 1), 2) <> String.duplicate(String.at(rest, 2), 2),
        else: rest

    <<r::8, g::8, b::8>> = Base.decode16!(rest, case: :mixed)
    <<r, g, b>>
  end
end
