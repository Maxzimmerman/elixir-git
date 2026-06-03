defmodule Commands.WriteTree do
  @behaviour Command

  def execute do
    {:ok, files} = File.ls(".")
    IO.inspect(Enum.reject(files, &File.dir?(&1)))
  end
end
