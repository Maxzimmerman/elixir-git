defmodule Commands.WriteTree do
  @behaviour Command

  def execute do
    IO.inspect(File.ls("."))
  end
end
