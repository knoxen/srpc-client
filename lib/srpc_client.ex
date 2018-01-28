defmodule SrpcClient do
  @moduledoc """
  Documentation for SrpcClient.
  """

  use Application

  require Logger

  def start(_type, []) do
    Process.register(self(), :SrpcClient)

    server_params = Application.get_env(:srpc_client, :server)

    children = [
      {SrpcClient.ConnectionServer, server_params},
      Supervisor.child_spec({SrpcClient.ConnectionsSupervisor, []}, type: :supervisor)
    ]

    opts = [
      strategy: :one_for_one,
      name: SrpcClient.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  def connect(:lib), do: connection(:lib)
  def connect(:user, id, password), do: connection({:user, id, password})

  def get(conn, path), do: conn |> GenServer.call({:get, path})

  def debug(conn, path), do: conn |> GenServer.call({:debug, path})

  defp connection(term) do
    case GenServer.call(SrpcClient.ConnectionServer, term) do
      {:ok, connection} ->
        connection

      {:error, reason} ->
        Logger.error("Failed creating lib connection")
        nil
    end
  end
end
