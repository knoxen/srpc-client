defmodule SrpcClient.Action do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  @lib_confirm 0x01
  # @lib_user_exchange 0x10
  # @lib_user_confirm 0x11
  # @user_exchange 0x20
  # @user_confirm 0x21
  # @registration 0xA0
  # @server_time 0xB0
  # @refresh 0xC0
  @close 0xFF

  def lib_exchange(url, data) do
    post(url, <<SrpcMsg.lib_exchange(), data::binary>>)
  end

  def lib_confirm(conn_info, data) do
    send(@lib_confirm, conn_info, data)
  end

  def close(conn_info, data) do
    send(@close, conn_info, data)
  end

  defp send(action, conn_info, data) do
    case packet(action, conn_info, data) do
      {:ok, packet} ->
        post(conn_info[:url], packet)

      error ->
        error
    end
  end

  defp packet(action, conn_info, data) do
    case SrpcLib.encrypt(:origin_client, conn_info, data) do
      {:ok, encrypted} ->
        conn_id = conn_info[:conn_id]
        id_size = :erlang.byte_size(conn_id)
        {:ok, <<SrpcMsg.action(), id_size::8, conn_id::binary, action, encrypted::binary>>}

      error ->
        error
    end
  end

  defp post(url, body) do
    case HTTPoison.post(url, body, [], proxy: {"localhost.charlesproxy.com", 8888}) do
      {:ok, %{:body => body, :status_code => 200}} ->
        {:ok, body}

      {:ok, %{:status_code => status_code}} ->
        {:error, "Status code = #{status_code}"}

      error ->
        error
    end
  end
end
