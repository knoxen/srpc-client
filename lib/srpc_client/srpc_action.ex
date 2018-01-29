defmodule SrpcClient.Action do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  alias SrpcClient.Util

  @lib_confirm 0x01
  # @lib_user_exchange 0x10
  # @lib_user_confirm 0x11
  # @user_exchange 0x20
  # @user_confirm 0x21
  # @registration 0xA0
  # @server_time 0xB0
  @refresh 0xC0
  @close 0xFF

  # @refresh_salt_size 16

  def lib_exchange(url, data) do
    Util.post(url, <<SrpcMsg.lib_exchange(), data::binary>>)
  end

  def lib_confirm(conn_info, data), do: send(@lib_confirm, conn_info, data)

  def refresh(conn_info, data), do: send(@refresh, conn_info, data)

  # def refresh(conn_info) do
  #   salt = :crypto.strong_rand_bytes(@refresh_salt_size)
  #   {nonce, data} = SrpcMsg.wrap(conn_info, salt)

  #   case send(@refresh, conn_info, data) do
  #     {:ok, encrypted_response} ->
  #       case SrpcLib.refresh_keys(conn_info, salt) do
  #         {:ok, conn_info} ->
  #           case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
  #             {:ok, refresh_response} ->
  #               case SrpcMsg.unwrap(nonce, refresh_response) do
  #                 {:ok, _data} ->
  #                   {:reply, :ok, conn_info}

  #                 error ->
  #                   reply_error(conn_info, "refresh unwrap", error)
  #               end

  #             error ->
  #               reply_error(conn_info, "refresh decrypt", error)
  #           end

  #         error ->
  #           reply_error(conn_info, "refresh keys", error)
  #       end

  #     error ->
  #       reply_error(conn_info, "refresh", error)
  #   end
  # end

  def close(conn_info, data), do: send(@close, conn_info, data)

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp send(action, conn_info, data) do
    case packet(action, conn_info, data) do
      {:ok, packet} ->
        Util.post(conn_info[:url], packet)

      error ->
        error
    end
  end

  defp packet(action, conn_info, data) do
    case SrpcLib.encrypt(:origin_requester, conn_info, data) do
      {:ok, encrypted} ->
        conn_id = conn_info[:conn_id]
        id_size = :erlang.byte_size(conn_id)
        {:ok, <<SrpcMsg.action(), id_size::8, conn_id::binary, action, encrypted::binary>>}

      error ->
        error
    end
  end
end
