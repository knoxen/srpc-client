defmodule SrpcClient.Connection do
  @moduledoc """
  Documentation for SrpcClient.Connection
  """

  alias :srpc_lib, as: SrpcLib

  alias SrpcClient.Msg, as: SrpcMsg
  alias SrpcClient.Action, as: SrpcAction
  alias SrpcClient.AppRequest

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
  def start_link(conn_info),
    do: GenServer.start_link(__MODULE__, conn_info, name: conn_info[:name])

  ## -----------------------------------------------------------------------------------------------
  ##  Init client
  ## -----------------------------------------------------------------------------------------------
  def init(conn_info) do
    {:ok,
     conn_info
     |> Map.put(:created, :erlang.system_time(:second))
     |> accessed()
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
  def handle_call(:info, _from, conn_info) do
    {:reply,
     %{
       name: conn_info[:name],
       created: conn_info[:created],
       accessed: :erlang.monotonic_time(:second) - conn_info[:accessed],
       keyed: :erlang.monotonic_time(:second) - conn_info[:keyed]
     }, conn_info}
  end

  def handle_call({:info, :raw}, _from, conn_info), do: {:reply, conn_info, conn_info}

  def handle_call({:request, params}, _from, conn_info) do
    {:reply, AppRequest.post(conn_info, params), conn_info |> accessed()}
  end

  def handle_call(:refresh, _from, conn_info), do: refresh(conn_info)

  def handle_call(:close, _from, conn_info), do: close(conn_info)

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  Refresh connection keys
  ## -----------------------------------------------------------------------------------------------
  defp refresh(conn_info) do
    salt = :crypto.strong_rand_bytes(@refresh_salt_size)

    conn_info
    |> SrpcMsg.wrap_encrypt(salt)
    |> refresh(salt, conn_info)
  end

  defp refresh({:error, _} = error, _salt, _conn_info), do: error

  defp refresh({nonce, packet}, salt, conn_info) do
    case SrpcAction.refresh(conn_info, packet) do
      {:ok, encrypted_response} ->
        case SrpcLib.refresh_keys(conn_info, salt) do
          {:ok, conn_info} ->
            case SrpcMsg.decrypt_unwrap(conn_info, nonce, encrypted_response) do
              {:ok, _data} ->
                {:reply, :ok, conn_info |> keyed()}
                
                error ->
                {:reply, error, conn_info}
            end

          error ->
            {:reply, error, conn_info}
        end
      error ->
        {:reply, error, conn_info}
    end
  end
  
  ## -----------------------------------------------------------------------------------------------
  ##  Close connection
  ## -----------------------------------------------------------------------------------------------
  defp close(conn_info) do
    conn_info
    |> SrpcMsg.wrap_encrypt()
    |> close(conn_info)
  end

  defp close({:error, _} = error, _conn_info), do: error

  defp close({nonce, packet}, conn_info) do
    case SrpcAction.close(conn_info, packet) do
      {:ok, encrypted_response} ->
        case SrpcMsg.decrypt_unwrap(conn_info, nonce, encrypted_response) do
          {:ok, _data} ->
            {:reply, :ok, conn_info}

          error ->
            {:reply, error, conn_info}
        end

      error ->
        {:reply, error, conn_info}
    end
  end

  defp keyed(conn_info), do: conn_info |> Map.put(:keyed, :erlang.monotonic_time(:second))
  defp accessed(conn_info), do: conn_info |> Map.put(:accessed, :erlang.monotonic_time(:second))
end
