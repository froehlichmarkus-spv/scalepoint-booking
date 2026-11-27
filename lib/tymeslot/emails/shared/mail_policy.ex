defmodule Tymeslot.Emails.Shared.MailPolicy do
  @moduledoc """
  Link and vendor rules for Growth OS mail base v3.

  Visible links stay on our hosts. Billing uses the signed portal URL.
  Vendor product names are removed from rendered mail.
  """

  @vendors [
    "SalesBlink",
    "FUTUREBLINK",
    "HeyLeads",
    "ScreamX",
    "IPRoyal",
    "TypeSafe AI",
    "ElevenLabs",
    "Tymeslot",
    "Twenty"
  ]

  @hosts [
    "book.scalepoint-ventures.com",
    "billing.scalepoint-ventures.com",
    "scalepoint-ventures.com",
    "outreach.scalepoint-ventures.com",
    "connect.scalepoint-ventures.com",
    "crm.scalepoint-ventures.com"
  ]

  @doc "The URL when it is mailto or one of our hosts, otherwise nil."
  @spec allowed_url(String.t() | nil) :: String.t() | nil
  def allowed_url(url) when is_binary(url) do
    trimmed = String.trim(url)

    cond do
      trimmed == "" -> nil
      String.starts_with?(trimmed, "mailto:") -> trimmed
      allowed_http?(trimmed) -> trimmed
      true -> nil
    end
  end

  def allowed_url(_url), do: nil

  @doc "Hosts of every http(s) href in `html`."
  @spec href_hosts(String.t()) :: [String.t()]
  def href_hosts(html) when is_binary(html) do
    ~r/href\s*=\s*"([^"]+)"/i
    |> Regex.scan(html)
    |> Enum.map(fn [_all, url] -> host_of(url) end)
    |> Enum.reject(&is_nil/1)
  end

  @doc "True when every href host is ours or a mailto address."
  @spec links_allowed?(String.t()) :: boolean()
  def links_allowed?(html) do
    ~r/href\s*=\s*"([^"]+)"/i
    |> Regex.scan(html)
    |> Enum.all?(fn [_all, url] -> allowed_url(url) end)
  end

  @doc "Replaces forbidden vendor names with BookDesk24."
  @spec scrub_vendors(String.t()) :: String.t()
  def scrub_vendors(text) when is_binary(text) do
    text
    |> String.split(~r/https?:\/\/[^\s<>"']+|mailto:[^\s<>"']+/i, include_captures: true)
    |> Enum.map_join(fn part ->
      if String.match?(part, ~r/^(?:https?:|mailto:)/i), do: part, else: replace_vendors(part)
    end)
  end

  defp replace_vendors(text) do
    Enum.reduce(@vendors, text, fn vendor, acc ->
      String.replace(acc, ~r/#{Regex.escape(vendor)}/i, "BookDesk24")
    end)
  end

  @doc "True when none of the forbidden vendor names remain."
  @spec vendors_clean?(String.t()) :: boolean()
  def vendors_clean?(text) do
    down = String.downcase(text)

    Enum.all?(@vendors, fn vendor ->
      not String.contains?(down, String.downcase(vendor))
    end)
  end

  @doc """
  WCAG AA contrast for the v3 mail pairs. Each item is
  `{foreground, background, minimum}`.
  """
  @spec contrast_pairs() :: [{String.t(), String.t(), float()}]
  def contrast_pairs do
    [
      {"#111E32", "#FFFFFF", 4.5},
      {"#3C4656", "#FFFFFF", 4.5},
      {"#835000", "#FFFFFF", 4.5},
      {"#4A5566", "#F4F7FB", 4.5},
      {"#0B6E66", "#FFFFFF", 4.5},
      {"#FFFFFF", "#111E32", 4.5},
      {"#0F6B47", "#E1F5EA", 4.5},
      {"#E6EBF2", "#131D2F", 4.5},
      {"#C3CDDA", "#131D2F", 4.5},
      {"#FFD98A", "#131D2F", 4.5},
      {"#5EE6D8", "#131D2F", 4.5},
      {"#A7B2C2", "#0B1220", 4.5},
      {"#0D1828", "#F4F7FB", 4.5}
    ]
  end

  defp allowed_http?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and is_binary(host) ->
        host = String.downcase(host)

        Enum.any?(@hosts, fn allowed ->
          host == allowed or String.ends_with?(host, "." <> allowed)
        end)

      _other ->
        false
    end
  end

  defp host_of("mailto:" <> _address), do: nil

  defp host_of(url) do
    case URI.parse(url) do
      %URI{host: host} when is_binary(host) -> String.downcase(host)
      _other -> nil
    end
  end
end
