defmodule SrpcClient.ConnectionSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def child_spec(_) do
    %{id: __MODULE__,
      start: {__MODULE__, :start_link, [[]]},
      type: :supervisor}
  end

  def start_link([]), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]), do: DynamicSupervisor.init(strategy: :one_for_one)
end
