defmodule SrpcClient.Connection do
  @moduledoc """
  Documentation for SrpcClient.Connection
  """
  alias :srpc_lib, as: SrpcLib
  alias SrpcClient.{Action, Msg, Opt}
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
     |> keyed()}
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

  def handle_call({:app, request}, _from, conn) do
    {:reply, conn |> Transport.app(request), conn |> used()}
  end

  def handle_call(:old?, _from, conn), do: {:reply, old_conn?(conn), conn}

  def handle_call(:tired?, _from, conn), do: {:reply, tired_conn?(conn), conn}

  def handle_call(:refresh, _from, conn), do: refresh(conn)

  def handle_call(:close, _from, conn), do: close(conn)

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
