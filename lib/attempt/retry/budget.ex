defmodule Attempt.Budget do
  @moduledoc """

  """
  use GenServer

  defstruct max_requests_per_second: 10

  def init(args) do
    {:ok, args}
  end

  def new(budget, options) when is_list(options) and is_atom(budget) do
    options =
      default_options()
      |> Keyword.merge(options)
      |> to_struct(__MODULE__)
  end

  @default_options Map.to_list(@struct)
  defp default_options do
    @default_options
  end

  defp to_struct(list, module) do
    struct(module, list)
  end
end
