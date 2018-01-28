defmodule SrpcClient.Connection do
  @moduledoc """
  Documentation for SrpcClient.Connection
  """

  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  require SrpcClient.Action
  alias SrpcClient.Action, as: SrpcAction

  ## =============================================================================================
  ##
  ##  GenServer
  ##
  ## =============================================================================================
  use GenServer

  ## =============================================================================================
  ##
  ##  Client
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  Start client
  ## -----------------------------------------------------------------------------------------------
  def start_link(conn_info),
    do: GenServer.start_link(__MODULE__, conn_info, name: conn_info[:name])

  ## ---------------------------------------------------------------------------------------------
  ##  Init client
  ## ---------------------------------------------------------------------------------------------
  def init(conn_info), do: {:ok, conn_info}

  ## =============================================================================================
  ##
  ## Public API
  ##
  ## =============================================================================================
  ## ---------------------------------------------------------------------------------------------
  ##  
  ## ---------------------------------------------------------------------------------------------
  def debug(path), do: GenServer.call(__MODULE__, {:debug, path})

  def name, do: GenServer.call(__MODULE__, :name)

  def get(path), do: GenServer.call(__MODULE__, {:get, path})

  def close, do: GenServer.stop(__MODULE__)
  ## =============================================================================================
  ##
  ##  GenServer Calls
  ##
  ## =============================================================================================
  ## ---------------------------------------------------------------------------------------------
  ##  
  ## ---------------------------------------------------------------------------------------------
  def handle_call({:debug, path}, _from, conn_info), do: {:reply, url(conn_info, path), conn_info}

  def handle_call(:name, _from, conn_info), do: {:reply, conn_info[:name], conn_info}

  def handle_call({:get, path}, _from, conn_info), do: {:reply, get(conn_info, path), conn_info}

  def handle_call(:close, _from, conn_info), do: close(conn_info)

  ## =============================================================================================
  ##
  ##  Private
  ##
  ## =============================================================================================
  ## ---------------------------------------------------------------------------------------------
  ## ---------------------------------------------------------------------------------------------
  defp url(conn_info, path), do: "#{conn_info[:url]}#{path}"

  defp get(conn_info, path) do
    url(conn_info, path) |> HTTPoison.get!()
  end

  defp close(conn_info) do
    {nonce, data} = SrpcMsg.wrap(conn_info)

    case SrpcAction.close(conn_info, data) do
      {:ok, encrypted_response} ->
        case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
          {:ok, close_response} ->
            case SrpcMsg.unwrap(conn_info, nonce, close_response) do
              {:ok, conn_info, _data} -> {:reply, :ok, conn_info}
              error -> reply_error(conn_info, "close unwrap", error)
            end

          error ->
            reply_error(conn_info, "close decrypt", error)
        end

      error ->
        reply_error(conn_info, "close", error)
    end
  end

  defp reply_error(conn_info, msg, error) do
    require Logger
    Logger.debug("#{conn_info[:name]} #{msg} error: #{inspect(error)}")

    {:reply, error, conn_info}
  end
end
