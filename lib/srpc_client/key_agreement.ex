defmodule SrpcClient.KeyAgreement do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  require SrpcClient.Action
  alias SrpcClient.Action, as: SrpcAction

  ## CxTBD Optional data processing

  ## User exchange codes
  @valid_user_id 1
  @invalid_user_id 2
  @invalid_password 3

  require Logger

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

  defp lib_confirm(error), do: error

  ## ===============================================================================================
  ##
  ##   User Key Agreement
  ##
  ## ===============================================================================================
  def user(conn_info, user_id, password) do
    conn_info
    |> lib_exchange
    |> lib_confirm
    |> user_exchange(user_id, password)
  end

  defp user_exchange({:ok, conn_info}, user_id, password) do
    {nonce, client_data} = SrpcMsg.wrap(conn_info)
    {client_keys, exch_req} = SrpcLib.create_user_key_exchange_request(user_id, client_data)

    case SrpcAction.lib_user_exchange(conn_info, exch_req) do
      {:ok, encrypted_response} ->
        case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
          {:ok, exchange_response} ->
            case SrpcLib.process_user_key_exchange_response(
                   user_id,
                   password,
                   client_keys,
                   exchange_response
                 ) do
              {:ok, user_conn_info, @valid_user_id, exchange_data} ->
                case SrpcMsg.unwrap(nonce, exchange_data) do
                  {:ok, _data} ->
                    conn_info
                    |> Map.take([:name, :url, :time_offset])
                    |> Map.merge(user_conn_info)
                    |> user_confirm

                  error ->
                    error
                end

              {:ok, user_conn_info, @invalid_user_id, _data} ->
                confirm_request = SrpcLib.create_user_key_confirm_request(user_conn_info)

                case SrpcAction.lib_user_confirm(conn_info, confirm_request) do
                  {:ok, _encrypted_response} ->
                    {:invalid, "Invalid user credentials"}

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

  defp user_exchange(error, _user_id, _password), do: error

  defp user_confirm(conn_info) do
    {nonce, client_data} = SrpcMsg.wrap(conn_info)
    confirm_request = SrpcLib.create_user_key_confirm_request(conn_info, client_data)

    case SrpcAction.lib_user_confirm(conn_info, confirm_request) do
      {:ok, encrypted_response} ->
        case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
          {:ok, confirm_response} ->
            case SrpcLib.process_user_key_confirm_response(conn_info, confirm_response) do
              {:ok, conn_info, confirm_data} ->
                case SrpcMsg.unwrap(nonce, confirm_data) do
                  {:ok, _data} ->
                    {:ok, conn_info}

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
end
