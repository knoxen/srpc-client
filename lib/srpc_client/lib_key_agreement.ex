defmodule SrpcClient.LibKeyAgreement do
  alias :srpc_lib, as: SrpcLib
  alias SrpcClient.Msg, as: SrpcMsg
  alias SrpcClient.Action, as: SrpcAction

  ## CxTBD Optional data processing

  require Logger

  ## ===============================================================================================
  ##
  ##   Lib Key Agreement
  ##
  ## ===============================================================================================
  def connect(conn_info) do
    conn_info
    |> exchange
    |> confirm
  end

  ## -----------------------------------------------------------------------------------------------
  ##   Lib Key Exchange
  ## -----------------------------------------------------------------------------------------------
  defp exchange(conn_info) do
    {client_keys, request} = SrpcLib.create_lib_key_exchange_request(SrpcLib.srpc_id())

    case SrpcAction.lib_exchange(conn_info[:url], request) do
      {:ok, response} ->
        case SrpcLib.process_lib_key_exchange_response(client_keys, response) do
          {:ok, exch_conn_info} ->
            {:ok, conn_info |> Map.merge(exch_conn_info) |> Map.put(:time_offset, 0)}

          error ->
            error
        end

      error ->
        error
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ##   Lib Key Exchange
  ## -----------------------------------------------------------------------------------------------
  defp confirm({:ok, conn_info}) do
    {nonce, client_data} = SrpcMsg.wrap(conn_info)
    confirm_request = SrpcLib.create_lib_key_confirm_request(conn_info, client_data)

    start_time = :erlang.system_time(:seconds)
    case SrpcAction.lib_confirm(conn_info, confirm_request) do
      {:ok, encrypted_response} ->
        delta = :erlang.system_time(:seconds) - start_time

        case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
          {:ok, confirm_response} ->
            case SrpcLib.process_lib_key_confirm_response(conn_info, confirm_response) do
              {:ok, conn_info, confirm_data} ->
                case SrpcMsg.unwrap(nonce, confirm_data, true) do
                  {:ok, _data, time} ->
                    time_offset = time - :erlang.system_time(:seconds) - trunc(delta / 2)

                    {:ok,
                     conn_info
                     |> Map.put(:time_offset, time_offset)}

                  error ->
                    error
                end

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

  defp confirm(error), do: error
end
