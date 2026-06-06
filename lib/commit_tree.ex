defmodule Commands.CommitTree do
  @behaviour Command

  def execute() do
    IO.inspect(System.argv())
  end

  def with_parent do
  end

  def without_parent do
  end
end
