defmodule SrpcClient.Connection do
  @moduledoc """
  Documentation for SrpcClient.Connection
  """
  alias :srpc_lib, as: SrpcLib
  alias SrpcClient.{Action, ConnectionSupervisor, Msg, Opt}
  alias SrpcClient.Conn.Info
  alias SrpcClient.TransportDelegate, as: Transport

  @refresh_salt_size 16

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
  ##  Start client
  ## -----------------------------------------------------------------------------------------------
  def start_link(conn), do: GenServer.start_link(__MODULE__, conn, name: conn.name)

  ## -----------------------------------------------------------------------------------------------
  ##  Init client
  ## -----------------------------------------------------------------------------------------------
  def init(conn) do
    now = mono_time()

    {:ok,
     conn
     |> Map.put(:created, now)
     |> keyed()
     |> Map.put(:pid, self())}
  end

  def old?, do: GenServer.call(__MODULE__, :old?)
  def tired?, do: GenServer.call(__MODULE__, :tired?)

  ## ===============================================================================================
  ##
  ##  GenServer calls
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##
  ## -----------------------------------------------------------------------------------------------
  def handle_call(:info, _from, conn) do
    now = mono_time()

    {:reply,
     %Info{
       name: conn.name,
       created: now - conn.created,
       accessed: now - conn.accessed,
       keyed: now - conn.keyed,
       count: conn.crypt_count
     }, conn}
  end

  def handle_call({:info, :full}, _from, conn), do: {:reply, conn, conn}

  def handle_call({:srpc, packet}, _from, conn), do: conn |> srpc(packet)

  def handle_call({:app, request}, _from, conn), do: conn |> app(request)

  def handle_call(:old?, _from, conn), do: {:reply, old_conn?(conn), conn}

  def handle_call(:tired?, _from, conn), do: {:reply, tired_conn?(conn), conn}

  def handle_call(:refresh, _from, conn), do: refresh(conn)

  def handle_call(:close, _from, conn), do: close(conn)

  def handle_cast(:terminate, conn) do
    ConnectionSupervisor |> Supervisor.terminate_child(conn.pid)
  end

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##
  ## -----------------------------------------------------------------------------------------------
  defp old_conn?(conn), do: old_conn?(conn, Opt.key_refresh())

  defp old_conn?(_conn, 0), do: false
  defp old_conn?(conn, refresh), do: refresh < mono_time() - conn.keyed

  defp tired_conn?(conn), do: tired_conn?(conn, Opt.key_limit())

  defp tired_conn?(_conn, 0), do: false
  defp tired_conn?(conn, key_limit), do: key_limit <= conn.crypt_count

  ## -----------------------------------------------------------------------------------------------
  ##
  ## -----------------------------------------------------------------------------------------------
  defp srpc(conn, packet) do
    conn |> transport(&Transport.srpc/2, packet, false)
  end

  defp app(conn, request) do
    conn |> transport(&Transport.app/2, request, true)
  end

  require Logger

  defp transport(conn, transport_fun, data, retry?) do
    case Opt.reconnect() do
      false ->
        {:reply, {conn |> transport_fun.(data), conn.pid}, conn |> used()}

      true ->
        conn
        |> transport_fun.(data)
        |> case do
          {:invalid, 403} ->
            case reconnect(conn) do
              {:ok, new_conn_pid} ->
                self() |> GenServer.cast(:terminate)
                if retry? do
                  result = new_conn_pid |> SrpcClient.info(:full) |> transport_fun.(data)
                  {:reply, {result, new_conn_pid}, conn |> used()}
                else
                  {:reply, {:noop, new_conn_pid}, conn}
                end
              not_ok ->
                {:reply, not_ok, nil}
            end

          result ->
            {:reply, {result, conn.pid}, conn |> used()}
        end
    end
  end

  defp reconnect(conn) do
    case conn.type do
      :lib ->
        SrpcClient.connect()

      :user ->
        SrpcClient.connect(conn.entity_id, conn.reconnect)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Refresh connection keys
  ## -----------------------------------------------------------------------------------------------
  defp refresh(conn) do
    salt = :crypto.strong_rand_bytes(@refresh_salt_size)

    conn
    |> Msg.wrap_encrypt(salt)
    |> refresh(salt, conn)
  end

  defp refresh({:error, _} = error, _salt, _conn), do: error

  defp refresh({nonce, packet}, salt, conn) do
    case Action.refresh(conn, packet) do
      {:ok, encrypted_response} ->
        case SrpcLib.refresh_keys(conn, salt) do
          {:ok, conn} ->
            case Msg.decrypt_unwrap(conn, nonce, encrypted_response) do
              {:ok, _data} ->
                {:reply, :ok, conn |> keyed()}

              error ->
                {:reply, error, conn}
            end

          error ->
            {:reply, error, conn}
        end

      error ->
        {:reply, error, conn}
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Close connection
  ## -----------------------------------------------------------------------------------------------
  defp close(conn) do
    conn
    |> Msg.wrap_encrypt()
    |> close(conn)
  end

  defp close({:error, _} = error, _conn), do: error

  defp close({nonce, packet}, conn) do
    case Action.close(conn, packet) do
      {:ok, encrypted_response} ->
        case Msg.decrypt_unwrap(conn, nonce, encrypted_response) do
          {:ok, _data} ->
            {:reply, :ok, conn}

          error ->
            {:reply, error, conn}
        end

      error ->
        {:reply, error, conn}
    end
  end

  defp keyed(conn) do
    conn
    |> Map.put(:keyed, mono_time())
    |> Map.put(:crypt_count, 0)
    |> accessed()
  end

  defp used(conn) do
    conn
    |> Map.put(:crypt_count, conn.crypt_count + 1)
    |> accessed()
  end

  defp accessed(conn), do: conn |> Map.put(:accessed, mono_time())

  defp mono_time, do: :erlang.monotonic_time(:second)
end
