defmodule SrpcClient.Connection do
  @moduledoc """
  Documentation for SrpcClient.Connection
  """

  alias :srpc_lib, as: SrpcLib

  alias SrpcClient.Msg, as: SrpcMsg
  alias SrpcClient.Action, as: SrpcAction
  alias SrpcClient.App, as: SrpcApp
  alias SrpcClient.Util

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
  def init(conn_info), do: {:ok, conn_info}

  ## ===============================================================================================
  ##
  ## Public API
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  
  ## -----------------------------------------------------------------------------------------------
  def name, do: GenServer.call(__MODULE__, :name)

  def get(path), do: GenServer.call(__MODULE__, {:get, path})

  def refresh, do: GenServer.call(__MODULE__, :refresh)

  def close, do: GenServer.call(__MODULE__, :close)

  ## ===============================================================================================
  ##
  ##  GenServer Calls
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  
  ## -----------------------------------------------------------------------------------------------
  def handle_call(:name, _from, conn_info), do: {:reply, conn_info[:name], conn_info}

  def handle_call({:get, path}, _from, conn_info), do: {:reply, get(conn_info, path), conn_info}

  def handle_call(:refresh, _from, conn_info), do: refresh(conn_info)

  def handle_call(:close, _from, conn_info), do: close(conn_info)

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp get(conn_info, path) do
    request(conn_info, :get, path)
  end

  defp request(conn_info, method, path, body \\ "", headers \\ []) do
    {nonce, packet} = SrpcApp.package(conn_info, method, path, body, headers)

    case Util.post(conn_info[:url], packet) do
      {:ok, encrypted_response} ->
        case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
          {:ok, response_data} ->
            case SrpcMsg.unwrap(nonce, response_data) do
              {:ok, data} ->
                require Logger
                Logger.debug("connection.request resp data = #{inspect(data)}")

              error ->
                error
            end

          error ->
            error
        end

      error ->
        error
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Refresh crypto keys
  ## -----------------------------------------------------------------------------------------------
  defp refresh(conn_info) do
    salt = :crypto.strong_rand_bytes(@refresh_salt_size)
    {nonce, data} = SrpcMsg.wrap(conn_info, salt)

    case SrpcAction.refresh(conn_info, data) do
      {:ok, encrypted_response} ->
        case SrpcLib.refresh_keys(conn_info, salt) do
          {:ok, conn_info} ->
            case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
              {:ok, refresh_response} ->
                case SrpcMsg.unwrap(nonce, refresh_response) do
                  {:ok, _data} ->
                    {:reply, :ok, conn_info}

                  error ->
                    reply_error(conn_info, "refresh unwrap", error)
                end

              error ->
                reply_error(conn_info, "refresh decrypt", error)
            end

          error ->
            reply_error(conn_info, "refresh keys", error)
        end

      error ->
        reply_error(conn_info, "refresh", error)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Close connection
  ## -----------------------------------------------------------------------------------------------
  defp close(conn_info) do
    {nonce, data} = SrpcMsg.wrap(conn_info)

    case SrpcAction.close(conn_info, data) do
      {:ok, encrypted_response} ->
        case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
          {:ok, close_response} ->
            case SrpcMsg.unwrap(nonce, close_response) do
              {:ok, _data} -> {:reply, :ok, conn_info}
              error -> reply_error(conn_info, "close unwrap", error)
            end

          error ->
            reply_error(conn_info, "close decrypt", error)
        end

      error ->
        reply_error(conn_info, "close", error)
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Log error message and GenServer reply with error
  ## -----------------------------------------------------------------------------------------------
  defp reply_error(conn_info, msg, error) do
    require Logger
    Logger.error("#{conn_info[:name]} #{msg} error: #{inspect(error)}")

    {:reply, error, conn_info}
  end
end
