defmodule TymeslotWeb.Brands.SalesRoom do
  @moduledoc """
  The left-hand identity of a booking page. Every line comes from the
  tenant document. A tenant without services, links, or a logo simply
  does not render those blocks.
  """
  use Phoenix.Component

  attr :profile, :map, default: nil
  attr :locale, :string, default: "en"

  def panel(assigns) do
    brand = Tymeslot.Brands.for_profile(assigns.profile)
    copy = copy_for(brand, assigns.locale)

    assigns =
      assigns
      |> assign(:brand, brand)
      |> assign(:copy, copy)
      |> assign(:services, (brand && brand.services) || [])
      |> assign(:links, safe_links(brand))

    ~H"""
    <div :if={@brand} class="room">
      <img :if={@brand.logo} class="room__logo" src={@brand.logo} alt={@brand.name} />
      <p :if={@brand.role != ""} class="room__role">{@brand.role}</p>
      <p :if={@copy["hero"]} class="room__hero">{@copy["hero"]}</p>
      <p :if={@copy["bio"]} class="room__bio">{@copy["bio"]}</p>
      <ul :if={@services != []} class="room__services">
        <li :for={service <- @services}>
          <strong>{service["title"]}</strong>
          <span>{service["text"]}</span>
        </li>
      </ul>
      <p :if={@brand.company != ""} class="room__company">{@brand.company}</p>
      <ul :if={@links != []} class="room__links">
        <li :for={link <- @links}>
          <a href={link["url"]}>{link["label"]}</a>
        </li>
      </ul>
    </div>
    """
  end

  defp copy_for(nil, _locale), do: %{}

  defp copy_for(brand, locale) do
    table = brand.copy || %{}
    key = if is_binary(locale) and String.starts_with?(locale, "de"), do: "de", else: "en"
    table[key] || table["en"] || %{}
  end

  defp safe_links(nil), do: []

  defp safe_links(brand) do
    Enum.filter(brand.links || [], fn link ->
      url = link["url"]
      label = link["label"]

      is_binary(url) and is_binary(label) and String.starts_with?(url, "https://") and
        (brand.house_brand or not Tymeslot.Brands.leak?(url <> label))
    end)
  end
end
