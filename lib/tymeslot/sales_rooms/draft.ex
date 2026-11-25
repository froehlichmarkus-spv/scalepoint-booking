defmodule Tymeslot.SalesRooms.Draft do
  @moduledoc """
  Edits a sales-room document in memory: form fields, added rows and removed files.
  """

  alias Tymeslot.SalesRooms.Storage

  @spec apply_form(map(), String.t(), map()) :: map()
  def apply_form(document, id, params) do
    put_in_block(document, id, fn block -> merge_fields(block, params) end)
  end

  defp merge_fields(%{"type" => "hero"} = block, params) do
    %{
      block
      | "headline" => value(params, "headline", block["headline"]),
        "subline" => value(params, "subline", block["subline"]),
        "image_alt" => value(params, "image_alt", block["image_alt"]),
        "image_kind" => kind(params["image_kind"], block["image_kind"])
    }
  end

  defp merge_fields(%{"type" => "offer"} = block, params) do
    %{block | "items" => map_items(block["items"], params, ["title", "text"])}
  end

  defp merge_fields(%{"type" => "gallery"} = block, params) do
    %{block | "images" => map_items(block["images"], params, ["alt"])}
  end

  defp merge_fields(%{"type" => "video"} = block, params) do
    %{
      block
      | "title" => value(params, "title", block["title"]),
        "url" => value(params, "url", block["url"])
    }
  end

  defp merge_fields(%{"type" => "testimonials"} = block, params) do
    %{
      block
      | "items" => map_items(block["items"], params, ["quote", "name", "company", "photo_alt"])
    }
  end

  defp merge_fields(%{"type" => "logos"} = block, params) do
    %{block | "items" => map_items(block["items"], params, ["alt"])}
  end

  defp merge_fields(%{"type" => "faq"} = block, params) do
    %{block | "items" => map_items(block["items"], params, ["question", "answer"])}
  end

  defp merge_fields(%{"type" => "cta"} = block, params) do
    %{
      block
      | "headline" => value(params, "headline", block["headline"]),
        "text" => value(params, "text", block["text"]),
        "button" => value(params, "button", block["button"])
    }
  end

  defp merge_fields(block, _params), do: block

  defp map_items(items, params, keys) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      Enum.reduce(keys, item, fn key, acc ->
        Map.put(acc, key, value(params, "#{key}_#{index}", acc[key]))
      end)
    end)
  end

  @spec add_item(map(), String.t()) :: map()
  def add_item(document, id) do
    put_in_block(document, id, fn block ->
      cond do
        block["type"] == "offer" and length(block["items"]) < 5 ->
          %{block | "items" => block["items"] ++ [%{"title" => "", "text" => ""}]}

        block["type"] == "testimonials" and length(block["items"]) < 6 ->
          %{
            block
            | "items" =>
                block["items"] ++
                  [
                    %{
                      "quote" => "",
                      "name" => "",
                      "company" => "",
                      "photo_path" => nil,
                      "photo_alt" => ""
                    }
                  ]
          }

        block["type"] == "faq" and length(block["items"]) < 10 ->
          %{block | "items" => block["items"] ++ [%{"question" => "", "answer" => ""}]}

        true ->
          block
      end
    end)
  end

  @spec remove_item(map(), String.t(), non_neg_integer()) :: map()
  def remove_item(document, id, index) do
    put_in_block(document, id, fn block ->
      key = list_key(block["type"])
      current = block[key] || []
      path = path_at(current, index)
      _deleted = Storage.delete(path)
      %{block | key => List.delete_at(current, index)}
    end)
  end

  defp list_key("offer"), do: "items"
  defp list_key("gallery"), do: "images"
  defp list_key("documents"), do: "files"
  defp list_key("testimonials"), do: "items"
  defp list_key("logos"), do: "items"
  defp list_key("faq"), do: "items"
  defp list_key(_type), do: "items"

  defp path_at(items, index) do
    case Enum.at(items, index) do
      %{"path" => path} -> path
      %{"photo_path" => path} -> path
      _none -> nil
    end
  end

  @spec put_in_block(map(), String.t(), (map() -> map())) :: map()
  def put_in_block(document, id, fun) do
    %{
      document
      | "blocks" =>
          Enum.map(document["blocks"], fn block ->
            if block["id"] == id, do: fun.(block), else: block
          end)
    }
  end

  @spec block(map(), String.t()) :: map()
  def block(document, id) do
    Enum.find(document["blocks"], &(&1["id"] == id)) || hd(document["blocks"])
  end

  defp value(params, key, fallback) do
    case Map.get(params, key) do
      nil -> fallback
      text -> text
    end
  end

  defp kind("logo", _fallback), do: "logo"
  defp kind("portrait", _fallback), do: "portrait"
  defp kind(_other, fallback), do: fallback
end
