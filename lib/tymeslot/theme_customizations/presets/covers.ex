defmodule Tymeslot.ThemeCustomizations.Presets.Covers do
  @moduledoc """
  The cover presets: the wide image across the top of a booking page, for a
  theme with an `Options.Cover` group, which lists the ids it offers.

  Each cover is `%{name:, src:, thumb:}`, `src` and `thumb` its public paths.
  The first four reuse the generated background visuals under
  `priv/static/images/themes/backgrounds/`, under the background presets'
  ids and names, so an organiser sees the same visual under the same name
  in both pickers. A cover of its own lives under
  `priv/static/images/themes/covers/` (`botanical`, `studio-light`,
  `paper-texture`). Every file is a generated gradient, not a photograph.
  """

  alias Tymeslot.ThemeCustomizations.Presets.Images

  @typedoc "A cover preset."
  @type cover_preset :: %{
          required(:name) => String.t(),
          required(:src) => String.t(),
          required(:thumb) => String.t(),
          optional(:source) => String.t()
        }

  @covers_dir "/images/themes/covers/"

  @covers %{
    "elegant-still-life" => %{
      name: "Elegant Still Life",
      src: Images.url("elegant-still-life.webp"),
      thumb: Images.url("elegant-still-life-thumbnail.webp")
    },
    "artistic-studio" => %{
      name: "Artistic Studio",
      src: Images.url("artistic-studio.webp"),
      thumb: Images.url("artistic-studio-thumbnail.webp")
    },
    "ocean-sunset" => %{
      name: "Ocean Sunset",
      src: Images.url("ocean-sunset.webp"),
      thumb: Images.url("ocean-sunset-thumbnail.webp")
    },
    "rustic-farmhouse" => %{
      name: "Rustic Farmhouse",
      src: Images.url("rustic-farmhouse.webp"),
      thumb: Images.url("rustic-farmhouse-thumbnail.webp")
    },
    "botanical" => %{
      name: "Botanical",
      src: @covers_dir <> "botanical.webp",
      thumb: @covers_dir <> "botanical-thumbnail.webp"
    },
    "studio-light" => %{
      name: "Studio Light",
      src: @covers_dir <> "studio-light.webp",
      thumb: @covers_dir <> "studio-light-thumbnail.webp"
    },
    "paper-texture" => %{
      name: "Paper Texture",
      src: @covers_dir <> "paper-texture.webp",
      thumb: @covers_dir <> "paper-texture-thumbnail.webp"
    }
  }

  @doc "Every cover preset, keyed by id."
  @spec all() :: %{String.t() => cover_preset()}
  def all, do: @covers
end
