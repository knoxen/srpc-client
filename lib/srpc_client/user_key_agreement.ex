defmodule SrpcClient.UserKeyAgreement do
  alias :srpc_lib, as: SrpcLib
  alias SrpcClient.Msg, as: SrpcMsg
  alias SrpcClient.Action, as: SrpcAction

  ## CxTBD Optional data processing

  ## User exchange codes
  @valid_user_id 1
  @invalid_user_id 2

  ## ===============================================================================================
  ##
  ##   User Key Agreement
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##   Connect
  ## -----------------------------------------------------------------------------------------------
  def connect({:ok, conn_info}, user_id, password), do: exchange(conn_info, user_id, password)
  def connect(error, _user_id, _password), do: error

  ## -----------------------------------------------------------------------------------------------
  ##   User key exchange
  ## -----------------------------------------------------------------------------------------------
  defp exchange(conn_info, user_id, password) do
    {nonce, client_data} = SrpcMsg.wrap(conn_info)

    {client_keys, request} =
      SrpcLib.create_user_key_exchange_request(conn_info, user_id, client_data)

    case SrpcAction.lib_user_exchange(conn_info, request) do
      {:ok, encrypted_response} ->
        case SrpcLib.process_user_key_exchange_response(
               conn_info,
               user_id,
               password,
               client_keys,
               encrypted_response
             ) do
          {:ok, user_conn_info, @valid_user_id, exchange_data} ->
            case SrpcMsg.unwrap(nonce, exchange_data) do
              {:ok, _data} ->
                conn_info
                |> Map.take([:name, :url, :time_offset])
                |> Map.merge(user_conn_info)
                |> confirm

              error ->
                error
            end

          {:ok, user_conn_info, @invalid_user_id, _data} ->
            confirm_request = SrpcLib.create_user_key_confirm_request(user_conn_info)

            case SrpcAction.lib_user_confirm(conn_info, confirm_request) do
              {:ok, _encrypted_response} ->
                {:invalid, "Invalid user"}

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
  ##   User key confirm
  ## -----------------------------------------------------------------------------------------------
  defp confirm(conn_info) do
    {nonce, client_data} = SrpcMsg.wrap(conn_info)
    confirm_request = SrpcLib.create_user_key_confirm_request(conn_info, client_data)

    case SrpcAction.lib_user_confirm(conn_info, confirm_request) do
      {:ok, encrypted_response} ->
        case SrpcLib.process_user_key_confirm_response(conn_info, encrypted_response) do
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
  end
end
