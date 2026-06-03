defmodule Commands.WriteTree do
  @behaviour Command

  def execute do
    IO.inspect(System.argv())
  end
end
