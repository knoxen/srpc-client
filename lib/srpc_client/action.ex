defmodule SrpcClient.Action do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg

  alias SrpcClient.TransportDelegate, as: Transport

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

  def lib_exchange(conn, data) do
    Transport.srpc(conn, <<Msg.lib_exchange(), data::binary>>)
  end

  def lib_confirm(conn, {:ok, packet}), do: conn |> action(@lib_confirm, packet)
  def lib_confirm(_conn, error), do: error

  def lib_user_exchange(conn, {:ok, packet}), do: conn |> action(@lib_user_exchange, packet)

  def lib_user_exchange(_conn, error), do: error

  def lib_user_confirm(conn, {:ok, packet}), do: conn |> action(@lib_user_confirm, packet)
  def lib_user_confirm(_conn, error), do: error

  def register(conn, packet), do: conn |> action(@registration, packet)

  def refresh(conn, packet), do: conn |> action(@refresh, packet)

  def close(conn, packet), do: conn |> action(@close, packet)

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp action(conn, action, data) do
    id_size = :erlang.byte_size(conn.conn_id)
    packet = <<Msg.action(), id_size::8, conn.conn_id::binary, action, data::binary>>

    conn
    |> Transport.srpc(packet)
  end
end
