defmodule SrpcClient.ConnectionServer do
  @moduledoc """
  Documentation for SrpcClient.ConnectionServer
  """

  # alias :srpc_lib, as: SrpcLib

  alias SrpcClient.{Conn, Connection, ConnectionSupervisor, KeyAgreement, Util}
  alias SrpcClient.TransportDelegate, as: Transport

  ## ===============================================================================================
  ##
  ##  GenServer
  ##
  ## ===============================================================================================
  use GenServer

  ## ===============================================================================================
  ##
  ##  Client
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  Child specification for starting server
  ## -----------------------------------------------------------------------------------------------
  def child_spec(_) do
    params = Application.get_env(:srpc_client, :server)
    %{id: __MODULE__, start: {__MODULE__, :start_link, [params]}, type: :supervisor}
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Start
  ## -----------------------------------------------------------------------------------------------
  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  ## -----------------------------------------------------------------------------------------------
  ##  Init client
  ## -----------------------------------------------------------------------------------------------
  def init(args) do
    unless args[:host], do: raise("Missing config for server host")
    {:ok, [host: args[:host], port: args[:port] || 80, lib_conn_num: 1, user_conn_num: 1]}
  end

  ## ===============================================================================================
  ##
  ##  GenServer Calls
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  Create lib connection
  ## -----------------------------------------------------------------------------------------------
  def handle_call(:lib, _from, state) do
    state
    |> conn_map(:lib)
    |> KeyAgreement.lib()
    |> connection
    |> case do
      {:ok, conn} ->
        {:reply, conn, state |> bump_conn_num(:lib)}

      error ->
        {:reply, error, state}
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Create user connection using auto-generated lib connection
  ## -----------------------------------------------------------------------------------------------
  def handle_call({:lib_user, id, password}, _from, state) do
    state
    |> conn_map(:user)
    |> KeyAgreement.lib_user(id, password)
    |> connection
    |> case do
      {:ok, conn} ->
        {:reply, conn, state |> bump_conn_num(:user)}

      no_conn ->
        {:reply, no_conn, state}
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Create user connection using existing connection
  ## -----------------------------------------------------------------------------------------------
  def handle_call({:user, conn, id, password}, _from, state) do
    state
    |> conn_map(:user)
    |> KeyAgreement.user(conn, id, password)
    |> connection
    |> case do
      {:ok, conn} ->
        {:reply, conn, state |> bump_conn_num(:user)}

      no_conn ->
        {:reply, no_conn, state}
    end
  end

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp conn_map(state, type) do
    %{
      type: type,
      name: conn_name(state, type),
      url: "http://#{state[:host]}:#{state[:port]}"
    }
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp conn_name(state, :lib), do: String.to_atom("LibConnection_#{state[:lib_conn_num]}")
  defp conn_name(state, :user), do: String.to_atom("UserConnection_#{state[:user_conn_num]}")

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp connection({:ok, conn_map}) do
    conn = struct(Conn, conn_map)
    {:ok, DynamicSupervisor.start_child(ConnectionSupervisor, {Connection, conn})}
  end

  defp connection({:invalid, 503}), do: Transport.refused()
  defp connection({:invalid, reason}), do: "Invalid #{inspect(reason)}"

  defp connection(error), do: error

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp bump_conn_num(state, :lib), do: bump_conn_num(state, :lib_conn_num)
  defp bump_conn_num(state, :user), do: bump_conn_num(state, :user_conn_num)

  defp bump_conn_num(state, conn_num) do
    state |> Keyword.replace!(conn_num, state[conn_num] + 1)
  end
end
