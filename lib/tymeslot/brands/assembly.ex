defmodule Tymeslot.Brands.Assembly do
  @moduledoc false

  @hex ~r/^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/

  @spec build(map()) :: term()
  def build(map) when is_map(map) do
    struct!(Tymeslot.Brands, Map.merge(identity(map), page(map)))
  end

  @spec fallback() :: term()
  def fallback do
    %Tymeslot.Brands{
      key: "neutral",
      enabled: true,
      default: true,
      house_brand: false,
      layout: "neutral",
      name: "BookDesk24",
      product_label: "BookDesk24",
      product_name: nil,
      suite_name: nil,
      module_name: nil,
      suite_title: nil,
      byline: nil,
      sender_name: "BookDesk24",
      sender_email: "booking@localhost",
      footer: "BookDesk24",
      powered_by: nil,
      logo: "/images/brand/neutral-mark.svg",
      chrome_logo: "/images/brand/neutral-mark.svg",
      favicon: "/images/brand/neutral-favicon.svg",
      portrait: false,
      accent: "#3E5C76",
      colors: %{
        "canvas" => "#E4DDD2",
        "card" => "#F7F4EF",
        "card_text" => "#1C1B19",
        "text" => "#1C1B19",
        "muted" => "#6E6A62",
        "accent" => "#3E5C76",
        "accent_strong" => "#2C455C"
      },
      fonts: %{"body" => "Inter", "heading" => "Inter"},
      hosts: [],
      username: "",
      owner_email: "",
      owner_name: "",
      timezone: "Europe/Berlin",
      role: "",
      company: "",
      legal: %{},
      links: [],
      copy: %{},
      services: [],
      availability: %{},
      events: [],
      notify_email: nil,
      webhook_url_env: ""
    }
  end

  defp identity(map) do
    %{
      key: Map.get(map, "key") || "tenant",
      enabled: Map.get(map, "enabled", true) != false,
      default: Map.get(map, "default") == true,
      house_brand: Map.get(map, "house_brand") == true,
      layout: Map.get(map, "layout") || "neutral",
      name: presence(Map.get(map, "name")) || "BookDesk24",
      product_label: Map.get(map, "product_label"),
      product_name: presence(Map.get(map, "product_name")),
      suite_name: presence(Map.get(map, "suite_name")),
      module_name: presence(Map.get(map, "module_name")),
      suite_title: presence(Map.get(map, "suite_title")),
      byline: presence(Map.get(map, "byline")),
      sender_name:
        presence(Map.get(map, "sender_name")) || presence(Map.get(map, "name")) || "BookDesk24",
      sender_email: presence(Map.get(map, "sender_email")) || "booking@localhost",
      footer: Map.get(map, "footer"),
      powered_by: presence(Map.get(map, "powered_by"))
    }
  end

  defp page(map) do
    %{
      logo: public_path(Map.get(map, "logo")),
      chrome_logo: public_path(Map.get(map, "chrome_logo") || Map.get(map, "logo")),
      favicon: public_path(Map.get(map, "favicon")),
      portrait: Map.get(map, "portrait") == true,
      accent: hex(Map.get(map, "accent"), nil),
      colors: Map.get(map, "colors") || %{},
      fonts: Map.get(map, "fonts") || %{},
      hosts: List.wrap(Map.get(map, "hosts")),
      username: Map.get(map, "username") || "",
      owner_email: Map.get(map, "owner_email") || "",
      owner_name: Map.get(map, "owner_name") || "",
      timezone: Map.get(map, "timezone") || "Europe/Berlin",
      role: Map.get(map, "role") || "",
      company: Map.get(map, "company") || "",
      legal: Map.get(map, "legal") || %{},
      links: List.wrap(Map.get(map, "links")),
      copy: Map.get(map, "copy") || %{},
      services: List.wrap(Map.get(map, "services")),
      availability: Map.get(map, "availability") || %{},
      events: List.wrap(Map.get(map, "events")),
      notify_email: Map.get(map, "notify_email"),
      webhook_url_env: Map.get(map, "webhook_url_env") || ""
    }
  end

  defp public_path("/" <> _path = path), do: path
  defp public_path(_path), do: nil

  defp presence(value) when is_binary(value) and value != "", do: value
  defp presence(_value), do: nil

  @spec hex(term(), term()) :: term()
  def hex(value, fallback) when is_binary(value) do
    if Regex.match?(@hex, value), do: value, else: fallback
  end

  def hex(_value, fallback), do: fallback
end
