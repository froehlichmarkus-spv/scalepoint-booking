defmodule Tymeslot.SalesRooms.Blocks do
  @moduledoc """
  The ordered block document a host edits. Unknown types are dropped.
  Limits are hard: five benefits, eight pictures, five brochures.
  """

  alias Tymeslot.SalesRooms.Embeds

  @types ~w(hero benefits gallery video brochures testimonials logos faq cta)
  @benefits_max 5
  @gallery_max 8
  @brochures_max 5
  @text_max 400
  @long_max 2000

  def types, do: @types
  def gallery_max, do: @gallery_max
  def brochures_max, do: @brochures_max
  def benefits_max, do: @benefits_max

  @doc "A full document, every block off, in the public order."
  def blank do
    Enum.with_index(@types, fn type, index ->
      %{
        "id" => type,
        "type" => type,
        "enabled" => false,
        "position" => index,
        "content" => default_content(type)
      }
    end)
  end

  def default_content("hero") do
    %{
      "headline" => "",
      "subline" => "",
      "logo_path" => nil,
      "logo_alt" => "",
      "show_profile_image" => true
    }
  end

  def default_content("benefits"), do: %{"items" => empty_items(3, %{"text" => ""})}
  def default_content("gallery"), do: %{"images" => []}
  def default_content("video"), do: %{"url" => "", "title" => "", "mp4_path" => nil}

  def default_content("brochures"), do: %{"files" => []}

  def default_content("testimonials") do
    %{"items" => empty_items(1, %{"quote" => "", "name" => "", "role" => ""})}
  end

  def default_content("logos"), do: %{"items" => []}

  def default_content("faq") do
    %{"items" => empty_items(1, %{"question" => "", "answer" => ""})}
  end

  def default_content("cta") do
    %{"headline" => "", "text" => "", "button_label" => ""}
  end

  def default_content(_), do: %{}

  @doc "Drops unknown blocks, clamps lists and trims text."
  def normalize(blocks) when is_list(blocks) do
    known =
      blocks
      |> Enum.filter(&(is_map(&1) and &1["type"] in @types))
      |> Enum.uniq_by(& &1["type"])

    missing = Enum.reject(@types, fn type -> Enum.any?(known, &(&1["type"] == type)) end)

    (known ++ Enum.map(missing, &%{"type" => &1}))
    |> Enum.with_index()
    |> Enum.map(fn {raw, index} ->
      type = raw["type"]

      %{
        "id" => type,
        "type" => type,
        "enabled" => raw["enabled"] == true,
        "position" => index,
        "content" => normalize_content(type, raw["content"] || %{})
      }
    end)
  end

  def normalize(_), do: blank()

  @doc "Errors that block a save. Incomplete copy is allowed and simply stays hidden."
  def validate(blocks) when is_list(blocks) do
    errors = limit_errors(blocks)
    normalized = normalize(blocks)

    errors =
      errors ++
        Enum.flat_map(normalized, fn
          %{"type" => "video", "content" => %{"url" => url}} when url != "" ->
            if match?({:ok, _}, Embeds.iframe_src(url)),
              do: [],
              else: [{:video, :embed_not_allowed}]

          _ ->
            []
        end)

    if errors == [], do: {:ok, normalized}, else: {:error, errors}
  end

  def validate(_), do: validate(blank())

  defp limit_errors(blocks) do
    Enum.flat_map(blocks, fn
      %{"type" => "benefits", "content" => %{"items" => items}} when is_list(items) ->
        if length(items) > @benefits_max, do: [{:benefits, :too_many}], else: []

      %{"type" => "gallery", "content" => %{"images" => images}} when is_list(images) ->
        if length(images) > @gallery_max, do: [{:gallery, :too_many}], else: []

      %{"type" => "brochures", "content" => %{"files" => files}} when is_list(files) ->
        if length(files) > @brochures_max, do: [{:brochures, :too_many}], else: []

      _ ->
        []
    end)
  end

  def put_enabled(blocks, id, enabled) do
    Enum.map(normalize(blocks), fn block ->
      if block["id"] == id, do: %{block | "enabled" => enabled == true}, else: block
    end)
  end

  def move(blocks, id, direction) when direction in [:up, :down] do
    blocks = normalize(blocks)
    index = Enum.find_index(blocks, &(&1["id"] == id))
    target = if direction == :up, do: index - 1, else: index + 1

    cond do
      is_nil(index) -> blocks
      target < 0 or target >= length(blocks) -> blocks
      true -> blocks |> swap(index, target) |> reindex()
    end
  end

  def put_content(blocks, id, content) when is_map(content) do
    Enum.map(normalize(blocks), fn block ->
      if block["id"] == id do
        merged = Map.merge(block["content"], stringify(content))
        %{block | "content" => normalize_content(block["type"], merged)}
      else
        block
      end
    end)
  end

  def find(blocks, id), do: Enum.find(normalize(blocks), &(&1["id"] == id))

  @doc "Blocks a guest may see: enabled and with something to read."
  def presentable(blocks) do
    blocks
    |> normalize()
    |> Enum.filter(&(&1["enabled"] and presentable?(&1)))
  end

  def presentable?(%{"type" => "hero", "content" => content}) do
    text?(content["headline"]) or text?(content["subline"]) or text?(content["logo_path"]) or
      content["show_profile_image"] == true
  end

  def presentable?(%{"type" => "benefits", "content" => %{"items" => items}}) do
    Enum.any?(items, &text?(&1["text"]))
  end

  def presentable?(%{"type" => "gallery", "content" => %{"images" => images}}) do
    Enum.any?(images, &(text?(&1["path"]) and text?(&1["alt"])))
  end

  def presentable?(%{"type" => "video", "content" => content}) do
    match?({:ok, _}, Embeds.iframe_src(content["url"])) or text?(content["mp4_path"])
  end

  def presentable?(%{"type" => "brochures", "content" => %{"files" => files}}) do
    Enum.any?(files, &text?(&1["path"]))
  end

  def presentable?(%{"type" => "testimonials", "content" => %{"items" => items}}) do
    Enum.any?(items, &(text?(&1["quote"]) and text?(&1["name"])))
  end

  def presentable?(%{"type" => "logos", "content" => %{"items" => items}}) do
    Enum.any?(items, &(text?(&1["path"]) and text?(&1["alt"])))
  end

  def presentable?(%{"type" => "faq", "content" => %{"items" => items}}) do
    Enum.any?(items, &(text?(&1["question"]) and text?(&1["answer"])))
  end

  def presentable?(%{"type" => "cta", "content" => content}) do
    text?(content["headline"]) or text?(content["button_label"])
  end

  def presentable?(_), do: false

  defp normalize_content(type, content) do
    base = default_content(type)
    content = if is_map(content), do: stringify(content), else: %{}

    case type do
      "hero" ->
        %{
          "headline" => clip(content["headline"], @text_max),
          "subline" => clip(content["subline"], @long_max),
          "logo_path" => blank(content["logo_path"]),
          "logo_alt" => clip(content["logo_alt"], 180),
          "show_profile_image" => content["show_profile_image"] != false
        }

      "benefits" ->
        %{
          "items" =>
            content
            |> list_of("items")
            |> Enum.take(@benefits_max)
            |> Enum.map(&clip_item(&1, ["text"]))
        }

      "gallery" ->
        %{
          "images" =>
            content |> list_of("images") |> Enum.take(@gallery_max) |> Enum.map(&image_item/1)
        }

      "video" ->
        %{
          "url" => clip(content["url"], 400),
          "title" => clip(content["title"], 180),
          "mp4_path" => blank(content["mp4_path"])
        }

      "brochures" ->
        %{
          "files" =>
            content |> list_of("files") |> Enum.take(@brochures_max) |> Enum.map(&file_item/1)
        }

      "testimonials" ->
        %{
          "items" =>
            content
            |> list_of("items")
            |> Enum.take(8)
            |> Enum.map(&clip_item(&1, ["quote", "name", "role"]))
        }

      "logos" ->
        %{"items" => content |> list_of("items") |> Enum.take(12) |> Enum.map(&image_item/1)}

      "faq" ->
        %{
          "items" =>
            content
            |> list_of("items")
            |> Enum.take(12)
            |> Enum.map(&clip_item(&1, ["question", "answer"]))
        }

      "cta" ->
        %{
          "headline" => clip(content["headline"], @text_max),
          "text" => clip(content["text"], @long_max),
          "button_label" => clip(content["button_label"], 60)
        }

      _ ->
        base
    end
  end

  defp image_item(item) do
    item = stringify(item)

    %{
      "id" => id_of(item),
      "path" => blank(item["path"]),
      "alt" => clip(item["alt"], 180),
      "name" => clip(item["name"], 80)
    }
  end

  defp file_item(item) do
    item = stringify(item)

    %{
      "id" => id_of(item),
      "path" => blank(item["path"]),
      "title" => clip(item["title"], 120),
      "filename" => clip(item["filename"], 180),
      "bytes" => bytes_of(item["bytes"])
    }
  end

  defp clip_item(item, keys) do
    item = stringify(item)

    Map.merge(
      %{"id" => id_of(item)},
      Map.new(keys, fn key ->
        max = if key in ["quote", "answer", "text"], do: @long_max, else: 180
        {key, clip(item[key], max)}
      end)
    )
  end

  defp list_of(content, key) do
    case content[key] do
      list when is_list(list) -> Enum.filter(list, &is_map/1)
      _ -> []
    end
  end

  defp empty_items(n, template) do
    Enum.map(1..n, fn _ -> Map.put(template, "id", random_id()) end)
  end

  defp id_of(%{"id" => id}) when is_binary(id) and id != "", do: id
  defp id_of(_), do: random_id()

  defp random_id, do: 8 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

  defp bytes_of(n) when is_integer(n) and n >= 0, do: n

  defp bytes_of(n) when is_binary(n) do
    case Integer.parse(n) do
      {parsed, ""} when parsed >= 0 -> parsed
      _ -> 0
    end
  end

  defp bytes_of(_), do: 0

  defp swap(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  defp reindex(blocks) do
    Enum.with_index(blocks, fn block, index -> %{block | "position" => index} end)
  end

  defp stringify(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      pair -> pair
    end)
  end

  defp clip(nil, _), do: ""
  defp clip(value, max) when is_binary(value), do: value |> String.trim() |> String.slice(0, max)

  defp clip(value, max) when is_atom(value) and not is_nil(value),
    do: value |> to_string() |> clip(max)

  defp clip(_, _), do: ""

  defp blank(value) do
    case clip(value, 300) do
      "" -> nil
      path -> if safe_path?(path), do: path
    end
  end

  defp safe_path?(path) do
    String.starts_with?(path, "sales_rooms/") and not String.contains?(path, "..")
  end

  defp text?(value) when is_binary(value), do: String.trim(value) != ""
  defp text?(_), do: false
end
