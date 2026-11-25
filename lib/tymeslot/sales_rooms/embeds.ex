defmodule Tymeslot.SalesRooms.Embeds do
  @moduledoc """
  Turns a host-supplied video URL into an iframe address on an allowlisted
  host. Anything else is refused. The iframe never receives the original
  query string.
  """

  @youtube_hosts ~w(youtube.com www.youtube.com m.youtube.com youtu.be youtube-nocookie.com www.youtube-nocookie.com)
  @vimeo_hosts ~w(vimeo.com www.vimeo.com player.vimeo.com)
  @loom_hosts ~w(loom.com www.loom.com)

  @youtube_id ~r/\A[A-Za-z0-9_-]{11}\z/
  @vimeo_id ~r/\A[0-9]{6,12}\z/
  @loom_id ~r/\A[a-fA-F0-9]{32}\z/

  @doc """
  Origins a sales-room iframe may load. The content-security policy frame-src
  directive uses this list and nothing broader.
  """
  @spec frame_origins() :: [String.t()]
  def frame_origins do
    [
      "https://www.youtube-nocookie.com",
      "https://player.vimeo.com",
      "https://www.loom.com"
    ]
  end

  @doc "The embed URL for `url`, or nil when the URL is not an allowlisted video."
  @spec embed_src(term()) :: String.t() | nil
  def embed_src(url) when is_binary(url) do
    with {:ok, uri} <- parse(url),
         id when is_binary(id) <- identifier(uri.host, uri.path || "/", uri.query) do
      src(uri.host, id)
    else
      _refused -> nil
    end
  end

  def embed_src(_other), do: nil

  defp parse(url) do
    case URI.parse(String.trim(url)) do
      %URI{scheme: "https", host: host, userinfo: nil} = uri
      when is_binary(host) and host != "" ->
        {:ok, %{uri | host: String.downcase(host)}}

      _refused ->
        :error
    end
  end

  defp identifier(host, path, query) when host in @youtube_hosts do
    youtube_id(host, path, query)
  end

  defp identifier(host, path, _query) when host in @vimeo_hosts, do: vimeo_id(path)
  defp identifier(host, path, _query) when host in @loom_hosts, do: loom_id(path)
  defp identifier(_host, _path, _query), do: nil

  defp youtube_id("youtu.be", "/" <> id, _query), do: accept(id, @youtube_id)

  defp youtube_id(_host, path, query) do
    if path in ["/watch", "/watch/"] do
      query |> query_value("v") |> accept(@youtube_id)
    else
      case Regex.run(~r/\A\/(?:embed|shorts)\/([A-Za-z0-9_-]{11})\z/, path) do
        [_match, id] -> id
        _miss -> nil
      end
    end
  end

  defp vimeo_id(path) do
    case Regex.run(~r/\A\/(?:video\/)?([0-9]{6,12})\z/, path) do
      [_match, id] -> accept(id, @vimeo_id)
      _miss -> nil
    end
  end

  defp loom_id(path) do
    case Regex.run(~r/\A\/(?:share|embed)\/([a-fA-F0-9]{32})\z/, path) do
      [_match, id] -> accept(id, @loom_id)
      _miss -> nil
    end
  end

  defp src(host, id) when host in @youtube_hosts,
    do: "https://www.youtube-nocookie.com/embed/" <> id

  defp src(host, id) when host in @vimeo_hosts, do: "https://player.vimeo.com/video/" <> id
  defp src(host, id) when host in @loom_hosts, do: "https://www.loom.com/embed/" <> id

  defp query_value(nil, _key), do: nil

  defp query_value(query, key) do
    query
    |> URI.decode_query()
    |> Map.get(key)
  end

  defp accept(nil, _pattern), do: nil

  defp accept(value, pattern) do
    if Regex.match?(pattern, value), do: value
  end
end
