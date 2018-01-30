defmodule SrpcClient.Action do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  alias SrpcClient.Util

  @lib_confirm 0x01
  @lib_user_exchange 0x10
  @lib_user_confirm 0x11
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

  def lib_user_exchange(conn_info, data), do: send(@lib_user_exchange, conn_info, data)
  
  def lib_user_confirm(conn_info, data), do: send(@lib_user_confirm, conn_info, data)

  def refresh(conn_info, data), do: send(@refresh, conn_info, data)

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
