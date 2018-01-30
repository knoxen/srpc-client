defmodule SrpcClient.KeyAgreement do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  require SrpcClient.Action
  alias SrpcClient.Action, as: SrpcAction

  require Logger

  def lib(conn_info) do
    case lib_exchange(conn_info) do
      {:ok, conn_info} ->
        case lib_confirm(conn_info) do
          {:ok, conn_info} ->
            conn_info

          error ->
            Logger.error("lib confirm error: #{inspect(error)}")
            error
        end

      error ->
        Logger.error("lib exchange error: #{inspect(error)}")
        error
    end
  end

  def user(_conn_info, _id, _password) do
  end

  defp lib_exchange(conn_info) do
    {client_keys, exch_req} = SrpcLib.create_lib_key_exchange_request(SrpcLib.srpc_id())

    case SrpcAction.lib_exchange(conn_info[:url], exch_req) do
      {:ok, exch_resp} ->
        case SrpcLib.process_lib_key_exchange_response(client_keys, exch_resp) do
          {:ok, exch_conn_info} ->
            {:ok, conn_info |> Map.merge(exch_conn_info) |> Map.put(:time_offset, 0)}

          error ->
            error
        end

      error ->
        Logger.error("KeyAgrement.lib_exchange error: #{inspect(error)}")
        error
    end
  end

  defp lib_confirm(conn_info) do
    {nonce, client_data} = SrpcMsg.wrap(conn_info)
    confirm_request = SrpcLib.create_lib_key_confirm_request(conn_info, client_data)

    start_time = :erlang.system_time(:seconds)

    case SrpcAction.lib_confirm(conn_info, confirm_request) do
      {:ok, encrypted_response} ->
        delta = :erlang.system_time(:seconds) - start_time

        case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
          {:ok, confirm_response} ->
            case SrpcLib.process_lib_key_confirm_response(conn_info, confirm_response) do
              {:ok, confirm_data} ->
                case SrpcMsg.unwrap(nonce, confirm_data, true) do
                  {:ok, _data, time} ->
                    time_offset = time - :erlang.system_time(:seconds) - trunc(delta / 2)

                    {:ok,
                     conn_info
                     |> Map.put(:time_offset, time_offset)
                     |> :srpc_util.remove_keys([:exch_public_key, :exch_key_pair, :exch_hash])}

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
        Logger.error("KeyAgreement.lib_confirm error: #{inspect(error)}")
        error
    end
  end
end
