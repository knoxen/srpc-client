defmodule SrpcClient.Action do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  use SrpcClient.Constant
  define(lib_confirm, 0x01)
  define(lib_user_exchange, 0x10)
  define(lib_user_confirm, 0x11)
  define(user_exchange, 0x20)
  define(user_confirm, 0x21)
  define(user_registration, 0xA0)
  define(user_server_time, 0xB0)
  define(user_refresh, 0xC0)
  define(user_close, 0xFF)

  def packet(conn_info, action_type, data) do
    case SrpcLib.encrypt(:origin_client, conn_info, data) do
      {:ok, encrypted} ->
        conn_id = conn_info[:conn_id]
        id_size = :erlang.byte_size(conn_id)
        {:ok, <<SrpcMsg.action(), id_size::8, conn_id::binary, action_type, encrypted::binary>>}

      error ->
        error
    end
  end
end
