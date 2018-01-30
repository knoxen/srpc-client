defmodule SrpcClient do
  @moduledoc """
  Documentation for SrpcClient.
  """

  alias SrpcClient.ConnectionServer
  alias SrpcClient.ConnectionsSupervisor, as: Connections

  use Application

  require Logger

  def start(_type, []) do
    Process.register(self(), :SrpcClient)

    server_params = Application.get_env(:srpc_client, :server)

    children = [
      {ConnectionServer, server_params},
      Supervisor.child_spec({Connections, []}, type: :supervisor)
    ]

    opts = [
      strategy: :one_for_one,
      name: SrpcClient.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  def connect(:lib), do: connection(:lib)
  def connect(:user, id, password), do: connection({:user, id, password})

  def echo(conn, path), do: conn |> GenServer.call({:echo, path})

  def get(conn, path, body \\ "", headers \\ []) do
    conn |> request({:get, path, body, headers})
  end

  def post(conn, path, body, headers \\ []) do
    conn |> request({:post, path, body, headers})
  end

  def request(conn, {method, path}), do: request(conn, {method, path, "", []})
  def request(conn, {method, path, body}), do: request(conn, {method, path, body, []})

  def request(conn, {_method, _path, _body, _headers} = params) do
    conn |> GenServer.call({:request, params})
  end

  def request(_conn, _params), do: {:error, "Invalid request parameters"}

  def refresh(conn), do: conn |> GenServer.call(:refresh)

  def close(conn) do
    conn |> GenServer.call(:close)
    Connections |> Supervisor.terminate_child(conn)
  end

  defp connection(term) do
    case GenServer.call(ConnectionServer, term) do
      {:ok, connection} ->
        connection

      {:error, reason} ->
        Logger.error("Failed creating lib connection: #{inspect(reason)}")
        nil
    end
  end
end
