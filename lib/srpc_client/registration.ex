defmodule SrpcClient.Registration do
  alias :srpc_lib, as: SrpcLib
  alias SrpcClient.Action, as: SrpcAction
  alias SrpcClient.Msg, as: SrpcMsg

  @registration_create 1
  # @registration_update 2
  # @registration_ok 10
  # @registration_dup 11
  # @registration_not_found 12

  require Logger

  # def register(user_id, password) do
  #   case SrpcClient.connect :lib do
  #     {:ok, conn} ->
  #       result = register(conn, user_id, password)
  #       Logger.debug "result = #{inspect result}"
  #       SrpcClient.close conn
  #       result

  #     error ->
  #       error
  #   end
  # end

  def register(_conn, _user_id, _password) do
    # def register(conn, user_id, password) do
    #   conn_info = conn |> SrpcClient.info(:raw)

    #   {nonce, client_data} = SrpcMsg.wrap(conn_info)

    #   case SrpcLib.create_registration_request(
    #         conn_info,
    #         @registration_create,
    #         user_id,
    #         password,
    #         client_data) do
    #     {ok, encrypted_request} ->

    #   registration_request = SrpcLib.create_registration_request(
    #     conn_info,
    #     @registration_create,
    #     user_id,
    #     password,
    #     client_data)

    #   case SrpcAction.register(conn_info, registration_request) do
    #     {:ok, encrypted_response} ->

    #       case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
    #         {:ok, registration_response} ->
    #           Logger.debug "reg resp: #{registration_response |> Base.encode16 |> inspect}"

    #           case SrpcMsg.unwrap(nonce, registration_response) do
    #             {:ok, data} ->
    #               Logger.debug "data = #{data |> Base.encode16 |> inspect}"
    #               data
    #             error ->
    #               error
    #           end

    #         error ->
    #           error
    #       end

    #     error ->
    #       error
    #   end
  end
end
