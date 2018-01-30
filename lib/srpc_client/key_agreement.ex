defmodule SrpcClient.KeyAgreement do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  require SrpcClient.Action
  alias SrpcClient.Action, as: SrpcAction

  ## CxTBD Optional data processing

  ## ===============================================================================================
  ##
  ##   Lib Key Agreement
  ##
  ## ===============================================================================================
  def lib(conn_info) do
    conn_info
    |> lib_exchange
    |> lib_confirm
  end
  ## -----------------------------------------------------------------------------------------------
  ##   Lib Key Exchange
  ## -----------------------------------------------------------------------------------------------
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
        error
    end
  end

  # defp lib_exchange(error), do: error
  
  ## -----------------------------------------------------------------------------------------------
  ##   Lib Key Exchange
  ## -----------------------------------------------------------------------------------------------
  defp lib_confirm({:ok, conn_info}) do
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
        error
    end
  end

  defp lib_confirm(error), do: error

  ## ===============================================================================================
  ##
  ##   User Key Agreement
  ##
  ## ===============================================================================================
  def user(conn_info, user_id, _password) do
    conn_info
    |> lib_exchange
    |> lib_confirm
    |> user_exchange(user_id)
  end

  defp user_exchange({:ok, conn_info}, user_id) do
    {client_keys, exch_req} = SrpcLib.create_user_key_exchange_request(user_id)

    case SrpcAction.lib_exchange(conn_info[:url], exch_req) do
      {:ok, exch_resp} ->
        conn_info = conn_info |> Map.replace!(:entity_id, user_id)
        conn_info

      error ->
        error
    end
    
  end

  defp user_exchange(error, _user_id), do: error
  
end
