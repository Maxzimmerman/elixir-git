defmodule Commands.CommitTree do
  @behaviour Command

  def execute() do
    IO.inspect(System.argv())
  end
end
