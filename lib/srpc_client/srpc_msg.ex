defmodule SrpcClient.Msg do
  use SrpcClient.Constant
  define(lib_exchange, 0x00)
  define(action, 0x10)
  define(app, 0xFF)

  @version 1
  @time_bits 32
  @nonce_size 10

  def wrap(conn_info) do
    wrap(conn_info, <<>>)
  end

  def wrap(conn_info, data) do
    time = :erlang.system_time(:second) + conn_info[:time_offset]
    nonce = :crypto.strong_rand_bytes(@nonce_size)

    {nonce,
     <<@version, time::size(@time_bits), @nonce_size,
       nonce::binary-size(@nonce_size), data::binary>>}
  end

  def unwrap(
        nonce,
        <<@version, time::size(@time_bits), @nonce_size,
          nonce::binary-size(@nonce_size), data::binary>>
      ) do
    {:ok, time, data}
  end

  def unwrap(_nonce, _packet), do: {:error, "Invalid Srpc Msg response packet"}
end
