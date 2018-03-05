defmodule SrpcClient.ConnectionSupervisor do
  @moduledoc false

  use DynamicSupervisor

  def child_spec(_) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [[]]}, type: :supervisor}
  end

  def start_link([]), do: DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)

  def init([]), do: DynamicSupervisor.init(strategy: :one_for_one)

  def connections do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, conn, _, _} -> named_conn(conn) end)
  end

  defp named_conn(conn) do
    %{name: name} = SrpcClient.info(conn)
    {name, conn}
  end
end
