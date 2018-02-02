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

  def lib_confirm(conn, {:ok, packet}), do: send(conn, @lib_confirm, packet)
  def lib_confirm(_conn, error), do: error

  def lib_user_exchange(conn, {:ok, packet}), do: send(conn, @lib_user_exchange, packet)
  def lib_user_exchange(_conn, error), do: error

  def lib_user_confirm(conn, {:ok, packet}), do: send(conn, @lib_user_confirm, packet)
  def lib_user_confirm(_conn, error), do: error

  def register(conn, packet), do: send(conn, @registration, packet)

  def refresh(conn, packet), do: send(conn, @refresh, packet)

  def close(conn, packet), do: send(conn, @close, packet)

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp send(conn, action, data, encrypt \\ false) do
    conn
    |> encrypt(data, encrypt)
    |> package(action, conn[:conn_id])
    |> post(conn)
  end

  defp encrypt(conn, data, true), do: SrpcLib.encrypt(:origin_requester, conn, data)
  defp encrypt(_conn, data, false), do: {:ok, data}

  defp package({:ok, data}, action, conn_id) do
    id_size = :erlang.byte_size(conn_id)
    {:ok, <<SrpcMsg.action(), id_size::8, conn_id::binary, action, data::binary>>}
  end

  defp package(error, _action, _conn), do: error

  defp post({:ok, packet}, conn), do: Util.post(conn[:url], packet)
  defp post(error, _conn), do: error
end
