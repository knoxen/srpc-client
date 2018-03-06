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
  def connect({:ok, conn}, user_id, password), do: connect(conn, user_id, password)

  def connect({:error, _} = error, _user_id, _password), do: error

  def connect(conn, user_id, password) do
    conn
    |> exchange(user_id, password)
    |> confirm
  end

  ## -----------------------------------------------------------------------------------------------
  ##   User key exchange
  ## -----------------------------------------------------------------------------------------------
  defp exchange(conn, user_id, password) do
    {nonce, client_data} = SrpcMsg.wrap(conn)

    {client_keys, request} =
      SrpcLib.create_user_key_exchange_request(conn, user_id, client_data)

    case SrpcAction.lib_user_exchange(conn, request) do
      {:ok, encrypted_response} ->
        case SrpcLib.process_user_key_exchange_response(
               conn,
               user_id,
               password,
               client_keys,
               encrypted_response
             ) do
          {:ok, user_conn, @valid_user_id, exchange_data} ->
            case SrpcMsg.unwrap(nonce, exchange_data) do
              {:ok, _data} ->
                {:ok,
                 conn
                 |> Map.take([:name, :url, :time_offset, :type])
                 |> Map.merge(user_conn)}

              error ->
                error
            end

          {:ok, user_conn, @invalid_user_id, _data} ->
            confirm_request = SrpcLib.create_user_key_confirm_request(user_conn)

            case SrpcAction.lib_user_confirm(conn, confirm_request) do
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
  defp confirm({:ok, conn}) do
    {nonce, client_data} = SrpcMsg.wrap(conn)
    confirm_request = SrpcLib.create_user_key_confirm_request(conn, client_data)

    case SrpcAction.lib_user_confirm(conn, confirm_request) do
      {:ok, encrypted_response} ->
        case SrpcLib.process_user_key_confirm_response(conn, encrypted_response) do
          {:ok, conn, confirm_data} ->
            case SrpcMsg.unwrap(nonce, confirm_data) do
              {:ok, _data} ->
                {:ok, conn}

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
