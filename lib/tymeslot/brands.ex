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

  alias Tymeslot.Brands.Assembly
  alias Tymeslot.BrandsQueries

  @legacy_name "Tyme" <> "slot"
  @house_tokens [
    "ScalePoint Ventures",
    "ScalePoint Booking",
    "ScalePoint Outreach OS",
    "ScalePoint"
  ]
  @fonts ~w(Inter Georgia) ++ ["DM Serif Display", "system-ui"]
  defstruct [
    :key,
    :enabled,
    :default,
    :house_brand,
    :layout,
    :name,
    :product_label,
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

  @doc "Enabled brands currently in effect, files overlaid by the database and env."
  @spec all() :: term()
  def all, do: Enum.filter(loaded(), & &1.enabled)

  @doc "Every brand document, including ones marked disabled."
  @spec documents() :: term()
  def documents, do: loaded()

  defp loaded do
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

  @spec reload() :: term()
  def reload do
    brands =
      files()
      |> db_overlay()
      |> Enum.map(&apply_env/1)
      |> Enum.map(&Assembly.build/1)

    :persistent_term.put({__MODULE__, :brands}, brands)
    :persistent_term.put({__MODULE__, :at}, System.monotonic_time(:millisecond))
    brands
  end

  @spec enabled() :: term()
  def enabled, do: all()

  @spec neutral_default() :: term()
  def neutral_default do
    case System.get_env("DEFAULT_BRAND_KEY") do
      key when is_binary(key) and key != "" ->
        needle = String.downcase(key)
        Enum.find(all(), &(String.downcase(&1.key) == needle)) || flagged_default()

      _unused ->
        flagged_default()
    end
  end

  defp flagged_default, do: Enum.find(all(), & &1.default) || Assembly.fallback()

  @spec for_username(term()) :: term()
  def for_username(nil), do: nil
  @spec for_username(term()) :: term()
  def for_username(""), do: nil

  @spec for_username(term()) :: term()
  def for_username(username) when is_binary(username) do
    needle = String.downcase(username)
    Enum.find(all(), &(String.downcase(&1.username || "") == needle))
  end

  @spec for_owner_email(term()) :: term()
  def for_owner_email(nil), do: nil

  @spec for_owner_email(term()) :: term()
  def for_owner_email(email) when is_binary(email) do
    needle = String.downcase(email)
    Enum.find(all(), &(String.downcase(&1.owner_email || "") == needle))
  end

  @spec for_host(term()) :: term()
  def for_host(nil), do: nil

  @spec for_host(term()) :: term()
  def for_host(host) when is_binary(host) do
    needle = host |> String.downcase() |> String.split(":") |> hd()
    Enum.find(all(), fn brand -> needle in Enum.map(brand.hosts || [], &String.downcase/1) end)
  end

  @spec for_user(term()) :: term()
  def for_user(%{id: id}), do: for_user_id(id)
  @spec for_user(term()) :: term()
  def for_user(_unused), do: nil

  @spec for_user_id(term()) :: term()
  def for_user_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {n, ""} -> for_user_id(n)
      _unused -> nil
    end
  end

  @spec for_user_id(term()) :: term()
  def for_user_id(id) when is_integer(id), do: lookup_user(id)

  @spec for_user_id(term()) :: term()
  def for_user_id(_unused), do: nil

  @doc """
  Binds the tenant of a known recipient.

  Owner address and username come from the brand document, so they resolve
  without a profile row. The user id is the fallback for any other account
  that belongs to a tenant. An unknown recipient keeps the neutral brand,
  which is what system mail uses when it is not about one tenant.
  """
  @spec bind_recipient(term()) :: term()
  def bind_recipient(user) when is_map(user) do
    bind(brand_for_recipient(user) || neutral_default())
  end

  @spec bind_recipient(term()) :: term()
  def bind_recipient(_unused), do: bind(neutral_default())

  @spec brand_for_recipient(term()) :: term()
  def brand_for_recipient(user) when is_map(user) do
    for_owner_email(map_value(user, :email)) ||
      for_username(map_value(user, :username)) ||
      for_user_id(map_value(user, :id) || map_value(user, :user_id))
  end

  @spec brand_for_recipient(term()) :: term()
  def brand_for_recipient(_unused), do: nil

  @spec for_profile(term()) :: term()
  def for_profile(%{username: username} = profile) do
    for_username(username) || for_user_id(Map.get(profile, :user_id))
  end

  @spec for_profile(term()) :: term()
  def for_profile(_unused), do: nil

  @spec bind(term()) :: term()
  def bind(brand) when is_struct(brand, __MODULE__) do
    Process.put({__MODULE__, :current}, brand)
    brand
  end

  @spec bind(term()) :: term()
  def bind(_unused), do: bind(neutral_default())

  @spec bind_user(term()) :: term()
  def bind_user(id), do: bind(for_user_id(id) || neutral_default())

  @spec bind_profile(term()) :: term()
  def bind_profile(profile), do: bind(for_profile(profile) || neutral_default())

  @spec bind_conn(term()) :: term()
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

  @spec current() :: term()
  def current, do: Process.get({__MODULE__, :current})

  @spec mail_identity() :: term()
  def mail_identity, do: current() || neutral_default()

  @spec chrome_name() :: term()
  def chrome_name do
    brand = mail_identity()
    brand.name
  end

  @spec chrome_suffix() :: term()
  def chrome_suffix, do: " · " <> chrome_name()

  @spec chrome_logo() :: term()
  def chrome_logo do
    brand = mail_identity()
    brand.chrome_logo || brand.logo
  end

  @spec chrome_alt() :: term()
  def chrome_alt do
    brand = mail_identity()

    if brand.house_brand && is_binary(brand.product_label) && brand.product_label != "" do
      brand.product_label
    else
      brand.name
    end
  end

  @spec favicon() :: term()
  def favicon do
    brand = mail_identity()
    brand.favicon || "/images/brand/neutral-favicon.svg"
  end

  @spec footer_label() :: term()
  def footer_label do
    brand = mail_identity()
    if is_binary(brand.footer) and brand.footer != "", do: brand.footer, else: brand.name
  end

  @spec footer_href() :: term()
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

  @spec powered_by(term()) :: term()
  def powered_by(brand) do
    case brand && brand.powered_by do
      text when is_binary(text) and text != "" -> text
      _unused -> nil
    end
  end

  @spec email_logo_path() :: term()
  def email_logo_path do
    brand = mail_identity()

    case brand.logo do
      "/" <> rest = web ->
        if String.ends_with?(web, ".png") do
          Application.app_dir(:tymeslot, Path.join("priv/static", rest))
        else
          nil
        end

      _unused ->
        nil
    end
  end

  @spec css(term()) :: term()
  def css(%__MODULE__{} = brand) do
    c = brand.colors || %{}

    """
    .folio-page[data-brand="#{safe_key(brand.key)}"],
    .folio-theme-wrapper:has(.folio-page[data-brand="#{safe_key(brand.key)}"]) {
      --room-canvas: #{Assembly.hex(c["canvas"], "#E4DDD2")};
      --room-card: #{Assembly.hex(c["card"], "#F7F4EF")};
      --room-card-text: #{Assembly.hex(c["card_text"], "#1C1B19")};
      --room-text: #{Assembly.hex(c["text"], "#1C1B19")};
      --room-muted: #{Assembly.hex(c["muted"], "#6E6A62")};
      --room-accent: #{Assembly.hex(c["accent"], "#3E5C76")};
      --room-accent-strong: #{Assembly.hex(c["accent_strong"], "#2C455C")};
      --room-heading: #{font(brand.fonts["heading"])};
      --room-body: #{font(brand.fonts["body"])};
    }
    """
  end

  @doc """
  Removes the upstream product name. On a tenant that is not the house brand,
  also removes the house company name, in any capitalisation.
  """
  @spec scrub(term(), term()) :: term()
  def scrub(text, brand \\ nil)

  @spec scrub(term(), term()) :: term()
  def scrub(text, brand) when is_binary(text) do
    brand = brand || mail_identity()
    text = replace_visible(text, @legacy_name, brand.name)

    if brand.house_brand do
      text
    else
      scrubbed =
        Enum.reduce(@house_tokens, text, fn token, acc ->
          replace_visible(acc, token, brand.name)
        end)

      replace_visible_regex(~r/\bspv\b/i, scrubbed, brand.name)
    end
  end

  @spec scrub(term(), term()) :: term()
  def scrub(other, _brand), do: other

  @spec scrub_email(term()) :: term()
  def scrub_email(%{from: from} = email) do
    brand = mail_identity()

    email
    |> Map.update!(:subject, &scrub(&1, brand))
    |> Map.update!(:html_body, &scrub(&1, brand))
    |> Map.update!(:text_body, &scrub(&1, brand))
    |> Map.put(:from, guard_from(from, brand))
  end

  @spec leak?(term()) :: term()
  def leak?(text) when is_binary(text) do
    down = String.downcase(text)

    String.contains?(down, "scalepoint") or
      String.contains?(down, String.downcase(@legacy_name)) or
      Regex.match?(~r/\bspv\b/i, text)
  end

  @spec leak?(term()) :: term()
  def leak?(_unused), do: false

  defp guard_from({name, addr}, %{house_brand: false, sender_email: sender} = brand)
       when is_binary(addr) and is_binary(sender) and sender != "" do
    addr = if leak?(addr), do: sender, else: addr
    {scrub(to_string(name), brand), addr}
  end

  defp guard_from({name, addr}, brand), do: {scrub(to_string(name), brand), addr}
  defp guard_from(other, _brand), do: other

  defp lookup_user(id) do
    for_username(BrandsQueries.profile_username(id)) ||
      for_owner_email(BrandsQueries.user_email(id))
  end

  defp map_value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end

  defp path_username(conn) do
    case conn.path_info do
      [name | _unused]
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

      _unused ->
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

      _unused ->
        priv_dir()
    end
  end

  defp priv_dir, do: Application.app_dir(:tymeslot, "priv/brands")

  defp read_file(path) do
    case File.read(path) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, map} when is_map(map) -> [map]
          _unused -> []
        end

      _unused ->
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
      Enum.reduce(BrandsQueries.tenant_brand_rows(), by_key, fn [key, doc], acc ->
        case decode_doc(doc) do
          map when is_map(map) -> Map.put(acc, key, Map.put(map, "key", key))
          _doc -> acc
        end
      end)

    Map.values(overlaid)
  end

  defp decode_doc(doc) when is_map(doc), do: doc

  defp decode_doc(doc) when is_binary(doc) do
    case Jason.decode(doc) do
      {:ok, map} -> map
      _unused -> nil
    end
  end

  defp decode_doc(_unused), do: nil

  defp apply_env(map) do
    map
    |> Map.put("name", env_over(map, "name_env", "name"))
    |> Map.put("sender_email", env_over(map, "sender_email_env", "sender_email"))
    |> Map.put("sender_name", env_over(map, "sender_name_env", "sender_name"))
    |> Map.put("footer", env_over(map, "footer_env", "footer"))
  end

  defp env_over(map, env_key, field) do
    case Map.get(map, env_key) do
      name when is_binary(name) and name != "" ->
        case System.get_env(name) do
          value when is_binary(value) and value != "" -> value
          _unused -> Map.get(map, field)
        end

      _unused ->
        Map.get(map, field)
    end
  end

  defp public_url(%{hosts: [host | _unused]}) when is_binary(host) and host != "" do
    scheme = System.get_env("URL_SCHEME") || "https"
    scheme <> "://" <> host
  end

  defp public_url(_unused), do: nil

  defp safe_key(key) do
    key = to_string(key)
    if Regex.match?(~r/^[a-z0-9-]{1,40}$/, key), do: key, else: "tenant"
  end

  defp font(value) when is_binary(value) and value in @fonts, do: value
  defp font(_unused), do: "Inter"

  # Visible prose only. A link, a hostname, or an address is an identifier:
  # replacing "scalepoint" inside `book.scalepoint-ventures.com` turns the
  # reset link into `book.BookDesk24-ventures.com`.
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
    Enum.map(Regex.scan(regex, text, return: :index), fn [{start, length}] ->
      {start, start + length}
    end)
  end
end
