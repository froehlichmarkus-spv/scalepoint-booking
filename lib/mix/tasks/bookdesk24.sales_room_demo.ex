defmodule Mix.Tasks.Bookdesk24.SalesRoomDemo do
  @shortdoc "Fill the local Nordlicht Analytics demo workspace"
  @moduledoc "Creates Lena Hartmann (Pro) and Mara Weber (Free) for screenshots."

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    info = Tymeslot.SalesRooms.Demo.seed!()
    Mix.shell().info("Pro page: #{info.pro}")
    Mix.shell().info("Free page: #{info.free}")
    Mix.shell().info("Editor: #{info.editor} as #{info.email}")
  end
end
