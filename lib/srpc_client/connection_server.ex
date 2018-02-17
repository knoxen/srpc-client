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
    state
    |> conn_info(:lib)
    |> KeyAgreement.lib
    |> conn_reply
    |> case do
         {:ok, conn} ->
           {:reply, conn, state |> bump_conn_num(:lib)}
         reply ->
           {:reply, reply, state}
       end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Create user connection using auto-generated lib connection
  ## -----------------------------------------------------------------------------------------------
  def handle_call({:lib_user, id, password}, _from, state) do
    state
    |> conn_info(:user)
    |> KeyAgreement.lib_user(id, password)
    |> conn_reply
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
    |> conn_info(:user)
    |> KeyAgreement.user(conn, id, password)
    |> conn_reply
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
  defp start_conn(conn_info) do
    DynamicSupervisor.start_child(ConnectionSupervisor, {Connection, conn_info})
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp conn_reply({:ok, conn_info}), do: {:ok, start_conn(conn_info)}

  defp conn_reply({:invalid, 503}), do: connection_refused()
  defp conn_reply({:invalid, _}), do: "Invalid user login"

  defp conn_reply({:error, %HTTPoison.Error{reason: :econnrefused}}), do: connection_refused()
  defp conn_reply(error), do: error
  
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp bump_conn_num(state, :lib),  do: bump_conn_num(state, :lib_conn_num)
  defp bump_conn_num(state, :user), do: bump_conn_num(state, :user_conn_num)
  defp bump_conn_num(state, conn_num) do
    state |> Keyword.replace!(conn_num, state[conn_num] + 1)
  end

  ## -----------------------------------------------------------------------------------------------
  ##  String representation of the url and optional proxy in use.
  ## -----------------------------------------------------------------------------------------------
  defp connection_refused do
    server = Application.get_env(:srpc_client, :server)

    proxy =
      if server[:proxy] do
        "via proxy #{server[:proxy]}"
      else
        ""
      end

    {:error, "Connection refused: http://#{server[:host]}:#{server[:port]} #{proxy}"}
  end
end
