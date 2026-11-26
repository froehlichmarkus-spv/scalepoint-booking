defmodule TymeslotWeb.SourceController do
  use TymeslotWeb, :controller

  alias Tymeslot.Brands
  alias Tymeslot.Licensing.SourceOffer

  @spec show(term(), term()) :: term()
  def show(conn, _params) do
    conn = conn |> put_root_layout(false) |> put_layout(false)
    brand = Brands.current() || Brands.neutral_default()
    colors = brand.colors || %{}
    canvas = colors["canvas"] || "#E4DDD2"
    text = colors["text"] || "#1C1B19"
    product = html_escape(Brands.product_name(brand))
    url = SourceOffer.url()

    link =
      if is_binary(url) and url != "" do
        href = html_escape(url)
        ~s(<p><a href="#{href}">#{href}</a></p>)
      else
        ""
      end

    html(conn, """
    <!DOCTYPE html>
    <html lang="de">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="robots" content="noindex" />
        <title>Quellcode · #{product}</title>
        <style>
          body { margin: 0; font-family: Inter, system-ui, sans-serif; background: #{canvas}; color: #{text}; }
          main { max-width: 38rem; padding: 3.5rem 1.4rem; }
          a { color: inherit; }
        </style>
      </head>
      <body>
        <main>
          <h1>Quellcode</h1>
          <p>#{product} ist freie Software unter der GNU AGPLv3. Wer diese Seite nutzt, kann den zugehörigen Quellcode verlangen.</p>
          #{link}
        </main>
      </body>
    </html>
    """)
  end

  defp html_escape(value) do
    value
    |> to_string()
    |> String.replace("&", "&amp;")
    |> String.replace("\"", "&quot;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end
end
