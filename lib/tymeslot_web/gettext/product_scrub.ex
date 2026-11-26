defmodule TymeslotWeb.Gettext.ProductScrub do
  @moduledoc """
  Gettext interpolation that removes the upstream product name.

  Every translated string, including an English msgid used as its own
  translation, passes through `Tymeslot.Brands.scrub/1`. On the house brand
  the upstream name becomes the brand name. On any other tenant it becomes
  that tenant's name, and the house company name is removed as well.

  Addresses and links are left untouched, the same way mail scrubbing works.
  """

  @behaviour Gettext.Interpolation

  alias Gettext.Interpolation.Default
  alias Tymeslot.Brands

  @impl Gettext.Interpolation
  def runtime_interpolate(message, bindings) do
    case Default.runtime_interpolate(message, bindings) do
      {:ok, text} ->
        {:ok, Brands.scrub(text)}

      {:missing_bindings, text, missing} ->
        {:missing_bindings, Brands.scrub(text), missing}
    end
  end

  @impl Gettext.Interpolation
  defmacro compile_interpolate(_message_type, message, bindings) do
    quote do
      unquote(__MODULE__).runtime_interpolate(unquote(message), unquote(bindings))
    end
  end

  @impl Gettext.Interpolation
  def message_format, do: "elixir-format"
end
