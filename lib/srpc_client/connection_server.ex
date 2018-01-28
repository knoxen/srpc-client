defmodule SrpcClient.ConnectionServer do
  @moduledoc """
  Documentation for SrpcClient.ConnectionServer
  """

  # alias :srpc_lib, as: SrpcLib

  alias SrpcClient.{ConnectionsSupervisor, Connection, LibKey, UserKey}

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
  ##  Start
  ## -----------------------------------------------------------------------------------------------
  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  ## -----------------------------------------------------------------------------------------------
  ##  Init client
  ## -----------------------------------------------------------------------------------------------
  def init([host: host, port: port] = args) when is_binary(host) and is_integer(port) do
    {:ok, args ++ [lib_conn_num: 1, user_conn_num: 1]}
  end

  def init(args) do
    {:stop, "Invalid args #{inspect(args)}"}
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
    {:reply, state |> connect |> connection,
     state |> Keyword.replace!(:lib_conn_num, state[:lib_conn_num] + 1)}
  end

  def handle_call({:user, id, password}, _from, state) do
    {:reply, state |> connect(id, password) |> connection,
     state |> Keyword.replace!(:user_conn_num, state[:lib_conn_num] + 1)}
  end

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp connect(state) do
    conn_num = state[:lib_conn_num]
    name = String.to_atom("LibConnection_#{conn_num}")

    conn_state =
      state
      |> Keyword.take([:host, :port])
      |> Keyword.put(:name, name)
      |> LibKey.agreement()

    {:lib, conn_state}
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp connect(state, id, password) do
    conn_num = state[:user_conn_num]
    name = String.to_atom("UserConnection_#{conn_num}")

    conn_state =
      state
      |> Keyword.take([:host, :port])
      |> Keyword.put(:name, name)
      |> UserKey.agreement(id, password)

    {:user, conn_state}
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp conn_state(state, name) do
    state |> Keyword.take([:host, :port]) |> Keyword.put(:name, name)
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp connection(conn_state) do
    DynamicSupervisor.start_child(ConnectionsSupervisor, {Connection, conn_state})
  end
end
