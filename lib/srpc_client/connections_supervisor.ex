defmodule SrpcClient.ConnectionsSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def start_link([]), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]), do: DynamicSupervisor.init(strategy: :one_for_one)
end
