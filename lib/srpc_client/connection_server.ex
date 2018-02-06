defmodule SrpcClient.ConnectionServer do
  @moduledoc """
  Documentation for SrpcClient.ConnectionServer
  """

  # alias :srpc_lib, as: SrpcLib

  alias SrpcClient.{ConnectionSupervisor, Connection, KeyAgreement}

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
    %{id: __MODULE__,
      start: {__MODULE__, :start_link, [params]},
      type: :supervisor}
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

    opts =
      case args[:proxy] do
        nil -> []
        proxy -> [proxy: proxy]
      end

    {:ok, [host: args[:host], port: args[:port] || 80, lib_conn_num: 1, user_conn_num: 1] ++ opts}
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
    {:reply, state |> conn_info(:lib) |> KeyAgreement.lib() |> start_conn,
     state |> Keyword.replace!(:lib_conn_num, state[:lib_conn_num] + 1)}
  end

  def handle_call({:lib_user, id, password}, _from, state) do
    {:reply, state |> conn_info(:user) |> KeyAgreement.lib_user(id, password) |> start_conn,
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
    conn_info = %{
      type: type,
      name: conn_name(state, type),
      url: "http://#{state[:host]}:#{state[:port]}"
    }

    case state[:proxy] do
      nil -> conn_info
      proxy -> conn_info |> Map.put(:proxy, proxy)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp conn_name(state, :lib), do: String.to_atom("LibConnection_#{state[:lib_conn_num]}")
  defp conn_name(state, :user), do: String.to_atom("UserConnection_#{state[:user_conn_num]}")

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp start_conn({:ok, conn_pid}) do
    DynamicSupervisor.start_child(ConnectionSupervisor, {Connection, conn_pid})
  end

  defp start_conn(error), do: error
end
