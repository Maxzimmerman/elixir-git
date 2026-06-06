defmodule Commands.CommitTree do
  @behaviour Command

  def execute() do
    create_commit(System.argv())
  end

  def create_commit([
        "commit-tree",
        tree_hash,
        "-p",
        parent_tree_hash,
        "-m",
        message
      ]) do
  end

  def create_commit([
        "commit-tree",
        tree_hash,
        "-m",
        message
      ]) do
  end
end
