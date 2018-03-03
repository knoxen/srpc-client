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
       keyed: now - conn.keyed
     }, conn}
  end

  def handle_call({:info, :full}, _from, conn), do: {:reply, conn, conn}

  def handle_call({:app, request}, _from, conn) do
    {:reply, conn |> Transport.app(request), conn |> accessed()}
  end

  def handle_call(:fresh_conn, _from, conn), do: fresh_conn(conn)

  def handle_call(:refresh, _from, conn), do: refresh(conn)

  def handle_call(:close, _from, conn), do: close(conn)

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
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
  ##  Ensure conn both fresh and of limited use
  ## -----------------------------------------------------------------------------------------------
  defp fresh_conn(conn) do
    fresh_conn =
      conn
      |> key_refresh(Opt.key_refresh())
      |> key_limit(Opt.key_limit())

    {:reply, self(), fresh_conn}
  end

  defp key_refresh(conn, 0) do
    conn
  end

  defp key_refresh(conn, refresh) do
    conn
  end

  defp key_limit(conn, 0) do
    conn
  end

  defp key_limit(conn, key_limit) do
    conn
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

  defp keyed(conn), do: conn |> Map.put(:keyed, mono_time()) |> accessed()
  defp accessed(conn), do: conn |> Map.put(:accessed, mono_time())

  defp mono_time, do: :erlang.monotonic_time(:second)
end
