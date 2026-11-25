defmodule Tymeslot.SalesRooms.Document do
  @moduledoc """
  The sales-room document: nine blocks, in the host's order, each switched
  on or off. Public rendering keeps only blocks that are on and complete,
  and only files that belong to the same profile.
  """

  alias Tymeslot.SalesRooms.Embeds

  @types ~w(hero offer gallery video documents testimonials logos faq cta)

  @limits %{
    headline: 140,
    subline: 320,
    title: 80,
    text: 280,
    quote: 500,
    name: 80,
    company: 80,
    question: 160,
    answer: 600,
    button: 40,
    alt: 180,
    file_name: 120,
    url: 400
  }

  @max_items %{
    offer: 5,
    gallery: 8,
    documents: 5,
    testimonials: 6,
    logos: 12,
    faq: 10
  }

  @path ~r/\Asales_rooms\/(\d+)\/(images|videos|documents)\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|jpeg|png|webp|mp4|webm|pdf)\z/

  @doc "A room with every block present and switched off."
  @spec blank() :: map()
  def blank, do: %{"blocks" => Enum.map(@types, &blank_block/1)}

  @doc "The block types, in their starting order."
  @spec types() :: [String.t()]
  def types, do: @types

  @spec max_items(String.t()) :: pos_integer() | nil
  def max_items(type), do: Map.get(@max_items, type)

  @doc """
  Canonicalises `document`. Unknown blocks are dropped. A missing type is
  appended, switched off, so the editor always offers the full set.
  """
  @spec normalize(term()) :: {:ok, map()} | {:error, term()}
  def normalize(document) when is_map(document) do
    raw = Map.get(document, "blocks") || Map.get(document, :blocks) || []

    if is_list(raw) do
      blocks =
        raw
        |> Enum.map(&stringify/1)
        |> Enum.filter(&valid_type?/1)
        |> Enum.uniq_by(& &1["id"])
        |> Enum.map(&cast_block/1)

      known = Map.new(blocks, &{&1["id"], &1})
      missing = Enum.reject(@types, &Map.has_key?(known, &1))

      {:ok, %{"blocks" => blocks ++ Enum.map(missing, &blank_block/1)}}
    else
      {:error, :invalid_document}
    end
  end

  def normalize(_other), do: {:error, :invalid_document}

  @doc "Replaces the block `id` with `fields` and checks limits."
  @spec put_block(map(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def put_block(document, id, fields) when is_binary(id) and is_map(fields) do
    with {:ok, %{"blocks" => blocks}} <- normalize(document),
         true <- id in @types,
         {:ok, block} <- cast_strict(id, fields, block_by_id(blocks, id)) do
      {:ok, %{"blocks" => replace(blocks, block)}}
    else
      false -> {:error, :unknown_block}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Switches a block on or off without touching its content."
  @spec toggle(map(), String.t(), boolean()) :: {:ok, map()} | {:error, term()}
  def toggle(document, id, enabled) when is_boolean(enabled) do
    with {:ok, %{"blocks" => blocks}} <- normalize(document),
         %{} = block <- block_by_id(blocks, id) do
      {:ok, %{"blocks" => replace(blocks, Map.put(block, "enabled", enabled))}}
    else
      nil -> {:error, :unknown_block}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Moves a block one step up or down."
  @spec move(map(), String.t(), :up | :down) :: {:ok, map()} | {:error, term()}
  def move(document, id, direction) when direction in [:up, :down] do
    with {:ok, %{"blocks" => blocks}} <- normalize(document),
         index when is_integer(index) <- Enum.find_index(blocks, &(&1["id"] == id)) do
      {:ok, %{"blocks" => swap(blocks, index, direction)}}
    else
      nil -> {:error, :unknown_block}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Blocks a visitor may see. File paths that do not belong to `profile_id`
  are removed. Images without an alt text are removed. An embed URL is
  replaced by its allowlisted iframe address.
  """
  @spec public_blocks(map() | nil, integer()) :: [map()]
  def public_blocks(nil, _profile_id), do: []

  def public_blocks(document, profile_id) when is_integer(profile_id) do
    case normalize(document) do
      {:ok, %{"blocks" => blocks}} ->
        blocks
        |> Enum.filter(&(&1["enabled"] == true))
        |> Enum.map(&public_block(&1, profile_id))
        |> Enum.reject(&is_nil/1)

      {:error, _reason} ->
        []
    end
  end

  def public_blocks(_document, _profile_id), do: []

  @doc "Whether `path` is a stored sales-room file of `kind` for `profile_id`."
  @spec owned_path?(term(), integer(), :image | :video | :document) :: boolean()
  def owned_path?(path, profile_id, kind)
      when is_binary(path) and is_integer(profile_id) and kind in [:image, :video, :document] do
    case Regex.run(@path, path) do
      [_full, id, folder, ext] ->
        id == Integer.to_string(profile_id) and folder == folder(kind) and ext in extensions(kind)

      _miss ->
        false
    end
  end

  def owned_path?(_path, _profile_id, _kind), do: false

  @doc "A download name that cannot escape the attachment header."
  @spec safe_filename(term()) :: String.t()
  def safe_filename(name) when is_binary(name) do
    cleaned =
      name
      |> Path.basename()
      |> String.replace(~r/[^A-Za-z0-9._-]/, "_")
      |> String.trim("._")
      |> String.slice(0, @limits.file_name)

    cond do
      cleaned in ["", ".", ".."] -> "document.pdf"
      String.ends_with?(String.downcase(cleaned), ".pdf") -> cleaned
      true -> cleaned <> ".pdf"
    end
  end

  def safe_filename(_name), do: "document.pdf"

  defp public_block(%{"type" => "hero"} = block, profile_id) do
    headline = present(block["headline"])
    image = image(block["image_path"], block["image_alt"], profile_id)

    if headline do
      %{
        "id" => "hero",
        "type" => "hero",
        "headline" => headline,
        "subline" => present(block["subline"]),
        "image_path" => image && image.path,
        "image_alt" => image && image.alt,
        "image_kind" => block["image_kind"]
      }
    end
  end

  defp public_block(%{"type" => "offer"} = block, _profile_id) do
    items =
      block["items"]
      |> Enum.filter(&(present(&1["title"]) || present(&1["text"])))
      |> Enum.take(@max_items.offer)
      |> Enum.map(&%{"title" => present(&1["title"]), "text" => present(&1["text"])})

    if items != [], do: %{"id" => "offer", "type" => "offer", "items" => items}
  end

  defp public_block(%{"type" => "gallery"} = block, profile_id) do
    images =
      block["images"]
      |> Enum.map(&image(&1["path"], &1["alt"], profile_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.take(@max_items.gallery)
      |> Enum.map(&%{"path" => &1.path, "alt" => &1.alt})

    if images != [], do: %{"id" => "gallery", "type" => "gallery", "images" => images}
  end

  defp public_block(%{"type" => "video"} = block, profile_id) do
    file = if owned_path?(block["file_path"], profile_id, :video), do: block["file_path"]
    src = if file, do: nil, else: Embeds.embed_src(block["url"])

    cond do
      file ->
        %{
          "id" => "video",
          "type" => "video",
          "file_path" => file,
          "title" => present(block["title"])
        }

      src ->
        %{
          "id" => "video",
          "type" => "video",
          "embed_src" => src,
          "title" => present(block["title"])
        }

      true ->
        nil
    end
  end

  defp public_block(%{"type" => "documents"} = block, profile_id) do
    files =
      block["files"]
      |> Enum.filter(&owned_path?(&1["path"], profile_id, :document))
      |> Enum.take(@max_items.documents)
      |> Enum.map(fn file ->
        %{
          "path" => file["path"],
          "name" => safe_filename(file["name"]),
          "bytes" => bytes(file["bytes"])
        }
      end)

    if files != [], do: %{"id" => "documents", "type" => "documents", "files" => files}
  end

  defp public_block(%{"type" => "testimonials"} = block, profile_id) do
    items =
      block["items"]
      |> Enum.filter(&(present(&1["quote"]) && present(&1["name"])))
      |> Enum.take(@max_items.testimonials)
      |> Enum.map(fn item ->
        photo = image(item["photo_path"], item["photo_alt"], profile_id)

        %{
          "quote" => present(item["quote"]),
          "name" => present(item["name"]),
          "company" => present(item["company"]),
          "photo_path" => photo && photo.path,
          "photo_alt" => photo && photo.alt
        }
      end)

    if items != [], do: %{"id" => "testimonials", "type" => "testimonials", "items" => items}
  end

  defp public_block(%{"type" => "logos"} = block, profile_id) do
    items =
      block["items"]
      |> Enum.map(&image(&1["path"], &1["alt"], profile_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.take(@max_items.logos)
      |> Enum.map(&%{"path" => &1.path, "alt" => &1.alt})

    if items != [], do: %{"id" => "logos", "type" => "logos", "items" => items}
  end

  defp public_block(%{"type" => "faq"} = block, _profile_id) do
    items =
      block["items"]
      |> Enum.filter(&(present(&1["question"]) && present(&1["answer"])))
      |> Enum.take(@max_items.faq)
      |> Enum.map(&%{"question" => present(&1["question"]), "answer" => present(&1["answer"])})

    if items != [], do: %{"id" => "faq", "type" => "faq", "items" => items}
  end

  defp public_block(%{"type" => "cta"} = block, _profile_id) do
    headline = present(block["headline"])
    button = present(block["button"])

    if headline || button do
      %{
        "id" => "cta",
        "type" => "cta",
        "headline" => headline,
        "text" => present(block["text"]),
        "button" => button
      }
    end
  end

  defp image(path, alt, profile_id) do
    alt = present(alt)

    if owned_path?(path, profile_id, :image) and alt do
      %{path: path, alt: alt}
    end
  end

  defp cast_strict(id, fields, current) do
    fields = stringify(fields)
    block = cast_block(Map.merge(current || blank_block(id), Map.put(fields, "id", id)))

    cond do
      too_many?(block) -> {:error, :too_many_items}
      missing_alt?(block) -> {:error, :alt_required}
      true -> {:ok, block}
    end
  end

  defp too_many?(%{"type" => "offer", "items" => items}), do: length(items) > @max_items.offer

  defp too_many?(%{"type" => "gallery", "images" => images}),
    do: length(images) > @max_items.gallery

  defp too_many?(%{"type" => "documents", "files" => files}),
    do: length(files) > @max_items.documents

  defp too_many?(%{"type" => "testimonials", "items" => items}),
    do: length(items) > @max_items.testimonials

  defp too_many?(%{"type" => "logos", "items" => items}), do: length(items) > @max_items.logos
  defp too_many?(%{"type" => "faq", "items" => items}), do: length(items) > @max_items.faq
  defp too_many?(_block), do: false

  defp missing_alt?(%{"type" => "hero", "image_path" => path, "image_alt" => alt}) do
    present(path) && !present(alt)
  end

  defp missing_alt?(%{"type" => "gallery", "images" => images}) do
    Enum.any?(images, &(present(&1["path"]) && !present(&1["alt"])))
  end

  defp missing_alt?(%{"type" => "testimonials", "items" => items}) do
    Enum.any?(items, &(present(&1["photo_path"]) && !present(&1["photo_alt"])))
  end

  defp missing_alt?(%{"type" => "logos", "items" => items}) do
    Enum.any?(items, &(present(&1["path"]) && !present(&1["alt"])))
  end

  defp missing_alt?(_block), do: false

  defp cast_block(%{"type" => "hero"} = block), do: hero(block)
  defp cast_block(%{"type" => "offer"} = block), do: offer(block)
  defp cast_block(%{"type" => "gallery"} = block), do: gallery(block)
  defp cast_block(%{"type" => "video"} = block), do: video(block)
  defp cast_block(%{"type" => "documents"} = block), do: documents(block)
  defp cast_block(%{"type" => "testimonials"} = block), do: testimonials(block)
  defp cast_block(%{"type" => "logos"} = block), do: logos(block)
  defp cast_block(%{"type" => "faq"} = block), do: faq(block)
  defp cast_block(%{"type" => "cta"} = block), do: cta(block)
  defp cast_block(_block), do: nil

  defp hero(block) do
    kind = if block["image_kind"] == "logo", do: "logo", else: "portrait"

    %{
      "id" => "hero",
      "type" => "hero",
      "enabled" => truthy(block["enabled"]),
      "headline" => clip(block["headline"], :headline),
      "subline" => clip(block["subline"], :subline),
      "image_path" => path_or_nil(block["image_path"]),
      "image_alt" => clip(block["image_alt"], :alt),
      "image_kind" => kind
    }
  end

  defp offer(block) do
    %{
      "id" => "offer",
      "type" => "offer",
      "enabled" => truthy(block["enabled"]),
      "items" =>
        list_of(block["items"], fn item ->
          %{"title" => clip(item["title"], :title), "text" => clip(item["text"], :text)}
        end)
    }
  end

  defp gallery(block) do
    %{
      "id" => "gallery",
      "type" => "gallery",
      "enabled" => truthy(block["enabled"]),
      "images" =>
        list_of(block["images"], fn image ->
          %{"path" => path_or_nil(image["path"]), "alt" => clip(image["alt"], :alt)}
        end)
    }
  end

  defp video(block) do
    %{
      "id" => "video",
      "type" => "video",
      "enabled" => truthy(block["enabled"]),
      "url" => clip(block["url"], :url),
      "file_path" => path_or_nil(block["file_path"]),
      "title" => clip(block["title"], :title)
    }
  end

  defp documents(block) do
    %{
      "id" => "documents",
      "type" => "documents",
      "enabled" => truthy(block["enabled"]),
      "files" =>
        list_of(block["files"], fn file ->
          %{
            "path" => path_or_nil(file["path"]),
            "name" => clip(file["name"], :file_name),
            "bytes" => bytes(file["bytes"])
          }
        end)
    }
  end

  defp testimonials(block) do
    %{
      "id" => "testimonials",
      "type" => "testimonials",
      "enabled" => truthy(block["enabled"]),
      "items" =>
        list_of(block["items"], fn item ->
          %{
            "quote" => clip(item["quote"], :quote),
            "name" => clip(item["name"], :name),
            "company" => clip(item["company"], :company),
            "photo_path" => path_or_nil(item["photo_path"]),
            "photo_alt" => clip(item["photo_alt"], :alt)
          }
        end)
    }
  end

  defp logos(block) do
    %{
      "id" => "logos",
      "type" => "logos",
      "enabled" => truthy(block["enabled"]),
      "items" =>
        list_of(block["items"], fn item ->
          %{"path" => path_or_nil(item["path"]), "alt" => clip(item["alt"], :alt)}
        end)
    }
  end

  defp faq(block) do
    %{
      "id" => "faq",
      "type" => "faq",
      "enabled" => truthy(block["enabled"]),
      "items" =>
        list_of(block["items"], fn item ->
          %{
            "question" => clip(item["question"], :question),
            "answer" => clip(item["answer"], :answer)
          }
        end)
    }
  end

  defp cta(block) do
    %{
      "id" => "cta",
      "type" => "cta",
      "enabled" => truthy(block["enabled"]),
      "headline" => clip(block["headline"], :headline),
      "text" => clip(block["text"], :text),
      "button" => clip(block["button"], :button)
    }
  end

  defp blank_block("hero"), do: hero(%{"id" => "hero", "type" => "hero"})
  defp blank_block("offer"), do: offer(%{"id" => "offer", "type" => "offer", "items" => []})
  defp blank_block("gallery"), do: gallery(%{"id" => "gallery", "type" => "gallery"})
  defp blank_block("video"), do: video(%{"id" => "video", "type" => "video"})
  defp blank_block("documents"), do: documents(%{"id" => "documents", "type" => "documents"})

  defp blank_block("testimonials"),
    do: testimonials(%{"id" => "testimonials", "type" => "testimonials"})

  defp blank_block("logos"), do: logos(%{"id" => "logos", "type" => "logos"})
  defp blank_block("faq"), do: faq(%{"id" => "faq", "type" => "faq"})
  defp blank_block("cta"), do: cta(%{"id" => "cta", "type" => "cta"})

  defp valid_type?(%{"id" => id, "type" => type}), do: id in @types and id == type
  defp valid_type?(_block), do: false

  defp block_by_id(blocks, id), do: Enum.find(blocks, &(&1["id"] == id))

  defp replace(blocks, block) do
    Enum.map(blocks, fn current ->
      if current["id"] == block["id"], do: block, else: current
    end)
  end

  defp swap(blocks, index, :up) when index > 0 do
    {earlier, [current | later]} = Enum.split(blocks, index)
    {head, [previous]} = Enum.split(earlier, -1)
    head ++ [current, previous] ++ later
  end

  defp swap(blocks, index, :down) when index < length(blocks) - 1 do
    {earlier, [current, nxt | later]} = Enum.split(blocks, index)
    earlier ++ [nxt, current] ++ later
  end

  defp swap(blocks, _index, _direction), do: blocks

  defp list_of(items, mapper) when is_list(items) do
    items
    |> Enum.map(&stringify/1)
    |> Enum.filter(&is_map/1)
    |> Enum.map(mapper)
  end

  defp list_of(_items, _mapper), do: []

  defp stringify(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), stringify(value)}
      {key, value} -> {key, stringify(value)}
    end)
  end

  defp stringify(list) when is_list(list), do: Enum.map(list, &stringify/1)
  defp stringify(other), do: other

  defp clip(value, key) do
    text =
      case value do
        text when is_binary(text) -> String.trim(text)
        _other -> ""
      end

    String.slice(text, 0, Map.fetch!(@limits, key))
  end

  defp path_or_nil(path) when is_binary(path) do
    path = String.trim(path)
    if path == "", do: nil, else: path
  end

  defp path_or_nil(_path), do: nil

  defp present(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      text -> text
    end
  end

  defp present(_value), do: nil

  defp truthy(value), do: value in [true, "true", "1", 1]

  defp bytes(value) when is_integer(value) and value >= 0 and value <= 20_000_000, do: value

  defp bytes(value) when is_binary(value) do
    case Integer.parse(value) do
      {parsed, ""} -> bytes(parsed)
      _miss -> 0
    end
  end

  defp bytes(_value), do: 0

  defp folder(:image), do: "images"
  defp folder(:video), do: "videos"
  defp folder(:document), do: "documents"

  defp extensions(:image), do: ~w(jpg jpeg png webp)
  defp extensions(:video), do: ~w(mp4 webm)
  defp extensions(:document), do: ~w(pdf)
end
