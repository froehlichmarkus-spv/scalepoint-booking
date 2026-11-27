defmodule TymeslotWeb.MarketingHTML do
  @moduledoc false
  use TymeslotWeb, :html
  use Gettext, backend: TymeslotWeb.Gettext

  embed_templates "marketing_html/*"
end
