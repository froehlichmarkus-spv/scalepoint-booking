defmodule TymeslotWeb.SourceController do
  use TymeslotWeb, :controller

  alias Tymeslot.Brands

  @spec show(term(), term()) :: term()
  def show(conn, _params) do
    conn = conn |> put_root_layout(false) |> put_layout(false)
    brand = Brands.current() || Brands.neutral_default()
    colors = brand.colors || %{}
    canvas = colors["canvas"] || "#E4DDD2"
    text = colors["text"] || "#1C1B19"
    url = System.get_env("SOURCE_OFFER_URL") || ""

    link =
      if url != "" and (brand.house_brand or not Brands.leak?(url)) do
        ~s(<p><a href="#{html_escape(url)}">Corresponding source</a></p>)
      else
        ""
      end

    html(conn, """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
        <title>Source</title>
        <style>
          body { margin: 0; font-family: Inter, system-ui, sans-serif; background: #{canvas}; color: #{text}; }
          main { max-width: 38rem; padding: 3.5rem 1.4rem; }
          a { color: inherit; }
        </style>
      </head>
      <body>
        <main>
          <h1>Source</h1>
          <p>This scheduling page is free software under the GNU AGPLv3. Anyone who receives it can ask the operator of this server for the corresponding source.</p>
          #{link}
        </main>
      </body>
    </html>
    """)
  end

  defp html_escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
