defmodule Tymeslot.SalesRooms.Embeds do
  @moduledoc """
  Turns a video URL into an iframe src on the allowlist, or refuses it.
  The raw URL is never written into the page.
  """

  @youtube_id ~r/\A[\w-]{11}\z/
  @vimeo_id ~r/\A\d{6,12}\z/
  @loom_id ~r/\A[a-f0-9]{32}\z/i

  @doc "The iframe src for a YouTube, Vimeo or Loom URL."
  @spec iframe_src(term()) :: {:ok, String.t()} | :error
  def iframe_src(url) when is_binary(url) do
    with {:ok, uri} <- parse(url) do
      host = uri.host |> to_string() |> String.downcase() |> String.replace_prefix("www.", "")
      path = uri.path || ""
      query = URI.decode_query(uri.query || "")

      cond do
        host in ["youtube.com", "youtube-nocookie.com", "m.youtube.com"] ->
          youtube(path, query)

        host == "youtu.be" ->
          youtube_id(String.trim_leading(path, "/"))

        host == "vimeo.com" ->
          vimeo(path)

        host == "player.vimeo.com" ->
          vimeo(path)

        host == "loom.com" ->
          loom(path)

        true ->
          :error
      end
    end
  end

  def iframe_src(_), do: :error

  defp parse(url) do
    uri = URI.parse(String.trim(url))

    if uri.scheme == "https" and is_binary(uri.host) do
      {:ok, uri}
    else
      :error
    end
  end

  defp youtube("/embed/" <> id, _query), do: youtube_id(id)
  defp youtube("/shorts/" <> id, _query), do: youtube_id(id)
  defp youtube("/watch", query), do: youtube_id(query["v"])
  defp youtube(_, _), do: :error

  defp youtube_id(id) when is_binary(id) do
    id = id |> String.split("/") |> hd() |> String.split("?") |> hd()

    if Regex.match?(@youtube_id, id) do
      {:ok, "https://www.youtube-nocookie.com/embed/" <> id}
    else
      :error
    end
  end

  defp youtube_id(_), do: :error

  defp vimeo(path) do
    id =
      path
      |> String.split("/", trim: true)
      |> Enum.find(&Regex.match?(@vimeo_id, &1))

    if id, do: {:ok, "https://player.vimeo.com/video/" <> id}, else: :error
  end

  defp loom("/share/" <> id), do: loom_id(id)
  defp loom("/embed/" <> id), do: loom_id(id)
  defp loom(_), do: :error

  defp loom_id(id) do
    id = id |> String.split("/") |> hd() |> String.split("?") |> hd()

    if Regex.match?(@loom_id, id) do
      {:ok, "https://www.loom.com/embed/" <> id}
    else
      :error
    end
  end
end
