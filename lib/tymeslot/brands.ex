defmodule Tymeslot.Brands do
  @moduledoc """
  Per-tenant brand. Loaded from JSON files, overlaid by the `tenant_brands`
  table when that table exists, then by environment variables named in the
  document. Nothing in a tenant's public page, mail, or calendar file is
  taken from another tenant.

  The process dictionary holds the brand for the current request or job.
  A tenant with `house_brand: false` is scrubbed of the upstream product
  name and of the house company's name before mail or a calendar file leaves.
  """

  import Ecto.Query, warn: false

  @legacy_name "Tyme" <> "slot"
  @house_tokens [
    "ScalePoint Ventures",
    "ScalePoint Booking",
    "ScalePoint Outreach OS",
    "ScalePoint"
  ]
  @fonts ~w(Inter Georgia) ++ ["DM Serif Display", "system-ui"]
  @hex ~r/^#(?:[0-9A-Fa-f]{3}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/

  defstruct [
    :key,
    :enabled,
    :default,
    :house_brand,
    :layout,
    :name,
    :product_label,
    :product_name,
    :suite_name,
    :module_name,
    :suite_title,
    :byline,
    :sender_name,
    :sender_email,
    :footer,
    :powered_by,
    :logo,
    :chrome_logo,
    :favicon,
    :portrait,
    :accent,
    :colors,
    :fonts,
    :hosts,
    :username,
    :owner_email,
    :owner_name,
    :timezone,
    :role,
    :company,
    :legal,
    :links,
    :copy,
    :services,
    :availability,
    :events,
    :notify_email,
    :webhook_url_env
  ]

  @doc "Brands currently in effect, files overlaid by the database and env."
  def all do
    now = System.monotonic_time(:millisecond)

    case :persistent_term.get({__MODULE__, :brands}, :miss) do
      :miss ->
        reload()

      brands ->
        at = :persistent_term.get({__MODULE__, :at}, now)

        if now - at > 5_000 do
          reload()
        else
          brands
        end
    end
  end

  def reload do
    brands =
      files()
      |> db_overlay()
      |> Enum.map(&apply_env/1)
      |> Enum.map(&build/1)
      |> Enum.filter(& &1.enabled)

    :persistent_term.put({__MODULE__, :brands}, brands)
    :persistent_term.put({__MODULE__, :at}, System.monotonic_time(:millisecond))
    brands
  end

  def enabled, do: all()

  def neutral_default do
    case System.get_env("DEFAULT_BRAND_KEY") do
      key when is_binary(key) and key != "" ->
        needle = String.downcase(key)
        Enum.find(all(), &(String.downcase(&1.key) == needle)) || flagged_default()

      _ ->
        flagged_default()
    end
  end

  defp flagged_default, do: Enum.find(all(), & &1.default) || fallback()

  def for_username(nil), do: nil
  def for_username(""), do: nil

  def for_username(username) when is_binary(username) do
    needle = String.downcase(username)
    Enum.find(all(), &(String.downcase(&1.username || "") == needle))
  end

  def for_owner_email(nil), do: nil

  def for_owner_email(email) when is_binary(email) do
    needle = String.downcase(email)
    Enum.find(all(), &(String.downcase(&1.owner_email || "") == needle))
  end

  def for_host(nil), do: nil

  def for_host(host) when is_binary(host) do
    needle = host |> String.downcase() |> String.split(":") |> hd()
    Enum.find(all(), fn brand -> needle in Enum.map(brand.hosts || [], &String.downcase/1) end)
  end

  def for_user(%{id: id}), do: for_user_id(id)
  def for_user(_), do: nil

  def for_user_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> for_user_id(n)
      _ -> nil
    end
  end

  def for_user_id(id) when is_integer(id), do: lookup_user(id)

  def for_user_id(_), do: nil

  @doc """
  Binds the tenant of a known recipient.

  Owner address and username come from the brand document, so they resolve
  without a profile row. The user id is the fallback for any other account
  that belongs to a tenant. An unknown recipient keeps the neutral brand,
  which is what system mail uses when it is not about one tenant.
  """
  def bind_recipient(user) when is_map(user) do
    bind(brand_for_recipient(user) || neutral_default())
  end

  def bind_recipient(_), do: bind(neutral_default())

  def brand_for_recipient(user) when is_map(user) do
    for_owner_email(map_value(user, :email)) ||
      for_username(map_value(user, :username)) ||
      for_user_id(map_value(user, :id) || map_value(user, :user_id))
  end

  def brand_for_recipient(_), do: nil

  def for_profile(%{username: username} = profile) do
    for_username(username) || for_user_id(Map.get(profile, :user_id))
  end

  def for_profile(_), do: nil

  def bind(brand) when is_struct(brand, __MODULE__) do
    Process.put({__MODULE__, :current}, brand)
    brand
  end

  def bind(_), do: bind(neutral_default())

  def bind_user(id), do: bind(for_user_id(id) || neutral_default())

  def bind_profile(profile), do: bind(for_profile(profile) || neutral_default())

  def bind_conn(conn) do
    user = conn.assigns[:current_user]
    path_name = path_username(conn)

    brand =
      (path_name && for_username(path_name)) ||
        (user && brand_for_recipient(user)) ||
        for_host(conn.host) ||
        neutral_default()

    bind(brand)
    conn
  end

  def current, do: Process.get({__MODULE__, :current})

  def mail_identity, do: current() || neutral_default()

  def chrome_name do
    brand = mail_identity()
    brand.name
  end

  def chrome_suffix, do: " · " <> chrome_name()

  @doc "Customer-facing product. Tenants override it; the house default is BookDesk24."
  def product_name(brand \\ nil) do
    brand = brand || mail_identity()

    cond do
      present?(brand.product_name) -> brand.product_name
      brand.house_brand -> "BookDesk24"
      true -> brand.name
    end
  end

  @doc "Internal suite, for example ScalePoint Ventures Growth OS."
  def suite_name(brand \\ nil) do
    brand = brand || mail_identity()
    if present?(brand.suite_name), do: brand.suite_name, else: "ScalePoint Ventures Growth OS"
  end

  @doc "Module name inside the suite, matching Outreach and Connect."
  def module_name(brand \\ nil) do
    brand = brand || mail_identity()
    if present?(brand.module_name), do: brand.module_name, else: "Booking"
  end

  @doc "Document title for admin, login and the dashboard."
  def suite_title(brand \\ nil) do
    brand = brand || mail_identity()

    cond do
      present?(brand.suite_title) -> brand.suite_title
      brand.house_brand -> "ScalePoint Growth OS · " <> module_name(brand)
      true -> product_name(brand)
    end
  end

  @doc "Small byline under the wordmark. Tenants on their own brand can leave it empty."
  def byline(brand \\ nil) do
    brand = brand || mail_identity()

    cond do
      present?(brand.byline) -> brand.byline
      brand.house_brand -> "by ScalePoint"
      true -> nil
    end
  end

  defp present?(value), do: is_binary(value) and value != ""

  def chrome_logo do
    brand = mail_identity()
    brand.chrome_logo || brand.logo
  end

  def chrome_alt do
    brand = mail_identity()

    if brand.house_brand && is_binary(brand.product_label) && brand.product_label != "" do
      brand.product_label
    else
      brand.name
    end
  end

  def favicon do
    brand = mail_identity()
    brand.favicon || "/images/brand/neutral-favicon.svg"
  end

  def footer_label do
    brand = mail_identity()
    if is_binary(brand.footer) and brand.footer != "", do: brand.footer, else: brand.name
  end

  def footer_href do
    brand = mail_identity()
    href = public_url(brand)

    cond do
      href in [nil, ""] -> "#"
      brand.house_brand -> href
      leak?(href) -> "#"
      true -> href
    end
  end

  def powered_by(brand) do
    case brand && brand.powered_by do
      text when is_binary(text) and text != "" -> text
      _ -> nil
    end
  end

  def email_logo_path do
    brand = mail_identity()

    case brand.logo do
      "/" <> rest = web ->
        if String.ends_with?(web, ".png") do
          Application.app_dir(:tymeslot, Path.join("priv/static", rest))
        else
          nil
        end

      _ ->
        nil
    end
  end

  def css(%__MODULE__{} = brand) do
    c = brand.colors || %{}

    """
    .folio-page[data-brand="#{safe_key(brand.key)}"],
    .folio-theme-wrapper:has(.folio-page[data-brand="#{safe_key(brand.key)}"]) {
      --room-canvas: #{hex(c["canvas"], "#E4DDD2")};
      --room-card: #{hex(c["card"], "#F7F4EF")};
      --room-card-text: #{hex(c["card_text"], "#1C1B19")};
      --room-text: #{hex(c["text"], "#1C1B19")};
      --room-muted: #{hex(c["muted"], "#5A687C")};
      --room-accent: #{hex(c["accent"], "#3E5C76")};
      --room-accent-strong: #{hex(c["accent_strong"], "#2C455C")};
      --room-heading: #{font(brand.fonts["heading"])};
      --room-body: #{font(brand.fonts["body"])};
    }
    """
  end

  @doc """
  Removes the upstream product name. On a tenant that is not the house brand,
  also removes the house company name, in any capitalisation.
  """
  def scrub(text, brand \\ nil)

  def scrub(text, brand) when is_binary(text) do
    brand = brand || mail_identity()
    text = replace_visible(text, @legacy_name, brand.name)

    if brand.house_brand do
      text
    else
      Enum.reduce(@house_tokens, text, fn token, acc ->
        replace_visible(acc, token, brand.name)
      end)
      |> then(&replace_visible_regex(~r/\bspv\b/i, &1, brand.name))
    end
  end

  def scrub(other, _brand), do: other

  @suite_footer "ScalePoint Ventures"
  @suite_footer_token "BOOKDESK_SUITE_FOOTER"

  def scrub_email(%{from: from} = email) do
    brand = mail_identity()

    email
    |> Map.update!(:subject, &scrub(&1, brand))
    |> Map.update!(:html_body, &restore_suite_footer(scrub(&1, brand)))
    |> Map.update!(:text_body, &restore_suite_footer(scrub(&1, brand)))
    |> Map.put(:from, guard_from(from, brand))
  end

  # The suite footer is one line on every mail, including a tenant page.
  # Scrub would otherwise rewrite the house name on those pages.
  defp restore_suite_footer(nil), do: nil

  defp restore_suite_footer(text) when is_binary(text),
    do: String.replace(text, @suite_footer_token, @suite_footer)

  def leak?(text) when is_binary(text) do
    down = String.downcase(text)

    String.contains?(down, "scalepoint") or
      String.contains?(down, @legacy_name |> String.downcase()) or
      Regex.match?(~r/\bspv\b/i, text)
  end

  def leak?(_), do: false

  defp guard_from({name, addr}, %{house_brand: false, sender_email: sender} = brand)
       when is_binary(addr) and is_binary(sender) and sender != "" do
    addr = if leak?(addr), do: sender, else: addr
    {scrub(to_string(name), brand), addr}
  end

  defp guard_from({name, addr}, brand), do: {scrub(to_string(name), brand), addr}
  defp guard_from(other, _brand), do: other

  defp lookup_user(id) do
    for_username(profile_username(id)) || for_owner_email(user_email(id))
  end

  defp profile_username(id) do
    Tymeslot.Repo.one(
      from p in Tymeslot.Profiles.ProfileSchema, where: p.user_id == ^id, select: p.username
    )
  rescue
    _ -> nil
  end

  defp user_email(id) do
    Tymeslot.Repo.one(from u in Tymeslot.Auth.UserSchema, where: u.id == ^id, select: u.email)
  rescue
    _ -> nil
  end

  defp map_value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp path_username(conn) do
    case conn.path_info do
      [name | _]
      when name not in [
             "auth",
             "admin",
             "dashboard",
             "source",
             "healthcheck",
             "assets",
             "users",
             "login",
             "dev"
           ] ->
        name

      _ ->
        nil
    end
  end

  defp files do
    dir = config_dir()

    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Enum.flat_map(&read_file/1)
  end

  defp config_dir do
    case System.get_env("BRAND_CONFIG_DIR") do
      dir when is_binary(dir) and dir != "" ->
        if File.dir?(dir), do: dir, else: priv_dir()

      _ ->
        priv_dir()
    end
  end

  defp priv_dir, do: Application.app_dir(:tymeslot, "priv/brands")

  defp read_file(path) do
    case File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, map} when is_map(map) -> [map]
          _ -> []
        end

      _ ->
        []
    end
  end

  defp db_overlay(maps) do
    if System.get_env("BRAND_DB_OVERRIDE") != "true" do
      maps
    else
      db_overlay_rows(maps)
    end
  end

  defp db_overlay_rows(maps) do
    by_key = Map.new(maps, fn map -> {Map.get(map, "key"), map} end)

    overlaid =
      case Tymeslot.Repo.query("select key, document from tenant_brands", []) do
        {:ok, %{rows: rows}} ->
          Enum.reduce(rows, by_key, fn [key, doc], acc ->
            case decode_doc(doc) do
              map when is_map(map) -> Map.put(acc, key, Map.put(map, "key", key))
              _ -> acc
            end
          end)

        _ ->
          by_key
      end

    Map.values(overlaid)
  rescue
    _ -> maps
  end

  defp decode_doc(doc) when is_map(doc), do: doc

  defp decode_doc(doc) when is_binary(doc) do
    case Jason.decode(doc) do
      {:ok, map} -> map
      _ -> nil
    end
  end

  defp decode_doc(_), do: nil

  defp apply_env(map) do
    map
    |> Map.put("name", env_over(map, "name_env", "name"))
    |> Map.put("sender_email", env_over(map, "sender_email_env", "sender_email"))
    |> Map.put("sender_name", env_over(map, "sender_name_env", "sender_name"))
    |> Map.put("footer", env_over(map, "footer_env", "footer"))
    |> Map.put("product_name", env_over(map, "product_name_env", "product_name"))
    |> Map.put("suite_name", env_over(map, "suite_name_env", "suite_name"))
    |> Map.put("module_name", env_over(map, "module_name_env", "module_name"))
    |> Map.put("suite_title", env_over(map, "suite_title_env", "suite_title"))
    |> Map.put("byline", env_over(map, "byline_env", "byline"))
  end

  defp env_over(map, env_key, field) do
    case Map.get(map, env_key) do
      name when is_binary(name) and name != "" ->
        case System.get_env(name) do
          value when is_binary(value) and value != "" -> value
          _ -> Map.get(map, field)
        end

      _ ->
        Map.get(map, field)
    end
  end

  defp build(map) do
    fonts = Map.get(map, "fonts") || %{}
    colors = Map.get(map, "colors") || %{}

    %__MODULE__{
      key: Map.get(map, "key") || "tenant",
      enabled: Map.get(map, "enabled", true) != false,
      default: Map.get(map, "default") == true,
      house_brand: Map.get(map, "house_brand") == true,
      layout: Map.get(map, "layout") || "neutral",
      name: presence(Map.get(map, "name")) || "Scheduler",
      product_label: Map.get(map, "product_label"),
      product_name: presence(Map.get(map, "product_name")),
      suite_name: presence(Map.get(map, "suite_name")),
      module_name: presence(Map.get(map, "module_name")),
      suite_title: presence(Map.get(map, "suite_title")),
      byline: presence(Map.get(map, "byline")),
      sender_name:
        presence(Map.get(map, "sender_name")) || presence(Map.get(map, "name")) || "Scheduler",
      sender_email: presence(Map.get(map, "sender_email")) || "booking@localhost",
      footer: Map.get(map, "footer"),
      powered_by: presence(Map.get(map, "powered_by")),
      logo: public_path(Map.get(map, "logo")),
      chrome_logo: public_path(Map.get(map, "chrome_logo") || Map.get(map, "logo")),
      favicon: public_path(Map.get(map, "favicon")),
      portrait: Map.get(map, "portrait") == true,
      accent: hex(Map.get(map, "accent"), "#3E5C76"),
      colors: colors,
      fonts: fonts,
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

  defp fallback do
    %__MODULE__{
      key: "neutral",
      enabled: true,
      default: true,
      house_brand: false,
      layout: "neutral",
      name: "Scheduler",
      product_label: "Scheduler",
      sender_name: "Scheduler",
      sender_email: "booking@localhost",
      footer: "Scheduler",
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

  defp public_url(%{hosts: [host | _]}) when is_binary(host) and host != "" do
    scheme = System.get_env("URL_SCHEME") || "https"
    scheme <> "://" <> host
  end

  defp public_url(_), do: nil

  defp public_path("/" <> _ = path), do: path
  defp public_path(_), do: nil

  defp presence(value) when is_binary(value) and value != "", do: value
  defp presence(_), do: nil

  defp safe_key(key) do
    key = to_string(key)
    if Regex.match?(~r/^[a-z0-9-]{1,40}$/, key), do: key, else: "tenant"
  end

  defp hex(value, fallback) when is_binary(value) do
    if Regex.match?(@hex, value), do: value, else: fallback
  end

  defp hex(_, fallback), do: fallback

  # A multi-word family has to be a quoted string inside the custom
  # property. `DM Serif Display` as bare idents is not a valid font-family
  # once substituted, so the declaration is dropped and the headline falls
  # through to the next stack (Georgia, then Times).
  defp font(value) when is_binary(value) and value in @fonts do
    if String.contains?(value, " "), do: "\"#{value}\"", else: value
  end

  defp font(_), do: "Inter"

  # Visible prose only. A link, a hostname, or an address is an identifier:
  # replacing "scalepoint" inside `book.scalepoint-ventures.com` turns the
  # reset link into `book.MeetDesk24-ventures.com`.
  defp replace_visible(text, needle, replacement) when is_binary(needle) do
    replace_visible_regex(~r/#{Regex.escape(needle)}/i, text, replacement)
  end

  defp replace_visible_regex(regex, text, replacement) do
    protected = protected_ranges(text)

    regex
    |> Regex.scan(text, return: :index)
    |> Enum.reverse()
    |> Enum.reduce(text, fn [{start, length}], acc ->
      if protected?(start, start + length, protected) do
        acc
      else
        <<head::binary-size(^start), _match::binary-size(^length), tail::binary>> = acc
        head <> replacement <> tail
      end
    end)
  end

  defp protected?(start, stop, ranges) do
    Enum.any?(ranges, fn {range_start, range_stop} ->
      start < range_stop and stop > range_start
    end)
  end

  defp protected_ranges(text) do
    [~r/href\s*=\s*(?:"[^"]*"|'[^']*')/i, ~r/https?:\/\/[^\s<>"']+/i, ~r/mailto:[^\s<>"']+/i]
    |> Enum.flat_map(&ranges(&1, text))
    |> Kernel.++(ranges(~r/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/, text))
    |> Kernel.++(
      ranges(~r/(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}/, text)
    )
  end

  defp ranges(regex, text) do
    Regex.scan(regex, text, return: :index)
    |> Enum.map(fn [{start, length}] -> {start, start + length} end)
  end
end
