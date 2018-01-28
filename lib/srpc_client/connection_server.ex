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
    {:reply, state |> conn_info(:lib) |> LibKey.agreement() |> connection,
     state |> Keyword.replace!(:lib_conn_num, state[:lib_conn_num] + 1)}
  end

  def handle_call({:user, id, password}, _from, state) do
    {:reply, state |> conn_info(:user) |> UserKey.agreement(id, password) |> connection,
     state |> Keyword.replace!(:user_conn_num, state[:user_conn_num] + 1)}
  end

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp conn_info(state, type) do
    %{type: type, name: conn_name(state, type), url: "http://#{state[:host]}:#{state[:port]}/"}
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp conn_name(state, :lib), do: String.to_atom("LibConnection_#{state[:lib_conn_num]}")
  defp conn_name(state, :user), do: String.to_atom("UserConnection_#{state[:user_conn_num]}")

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp connection(conn_state) do
    DynamicSupervisor.start_child(ConnectionsSupervisor, {Connection, conn_state})
  end
end
