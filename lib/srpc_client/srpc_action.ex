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
  @registration 0xA0
  # @server_time 0xB0
  @refresh 0xC0
  @close 0xFF

  # @refresh_salt_size 16

  def lib_exchange(url, data) do
    Util.post(url, <<SrpcMsg.lib_exchange(), data::binary>>)
  end

  def lib_confirm(conn_info, {:ok, data}), do: send(conn_info, @lib_confirm, data)
  def lib_confirm(conn_info, error), do: error

  def lib_user_exchange(conn_info, data), do: send(conn_info, @lib_user_exchange, data, true)

  def lib_user_confirm(conn_info, {:ok, data}), do: send(conn_info, @lib_user_confirm, data)
  def lib_user_confirm(conn_info, error), do: error

  def register(conn_info, data), do: send(conn_info, @registration, data)

  def refresh(conn_info, data), do: send(conn_info, @refresh, data, true)

  def close(conn_info, data), do: send(conn_info, @close, data, true)

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp send(conn_info, action, data, encrypt \\ false) do
    conn_info
    |> encrypt(data, encrypt)
    |> package(action, conn_info[:conn_id])
    |> post(conn_info)
  end

  defp encrypt(conn_info, data, true), do: SrpcLib.encrypt(:origin_requester, conn_info, data)
  defp encrypt(_conn_info, data, false), do: {:ok, data}

  defp package({:ok, data}, action, conn_id) do
    id_size = :erlang.byte_size(conn_id)
    {:ok, <<SrpcMsg.action(), id_size::8, conn_id::binary, action, data::binary>>}
  end

  defp package(error, _action, _conn_info), do: error

  defp post({:ok, packet}, conn_info), do: Util.post(conn_info[:url], packet)
  defp post(error, _conn_info), do: error
end
