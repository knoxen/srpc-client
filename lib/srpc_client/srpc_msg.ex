defmodule SrpcClient.Msg do
  use SrpcClient.Constant
  define(lib_exchange, 0x00)
  define(action, 0x10)
  define(app, 0xFF)

  @version 1
  @time_bits 32
  @nonce_bytes 4

  @response_age_tolerance 30

  def wrap(conn_info) do
    wrap(conn_info, <<>>)
  end

  def wrap(conn_info, data) do
    their_time = :erlang.system_time(:second) + conn_info[:time_offset]
    nonce = :crypto.strong_rand_bytes(@nonce_bytes)
    {nonce, <<@version, their_time::size(@time_bits), @nonce_bytes, nonce::binary, data::binary>>}
  end

  def unwrap(conn_info, nonce, packet, check_age \\ true)

  def unwrap(
        conn_info,
        nonce,
        <<@version, their_time::size(@time_bits), @nonce_bytes, nonce::binary-size(@nonce_bytes),
          data::binary>>,
        check_age
      ) do
    if check_age do
      {:ok, conn_info, data}
    else
      {:ok, conn_info |> Map.put(:time_offset, their_time), data}
    end
  end

  def unwrap(_conn_info, _nonce, _packet, _check_age),
    do: {:error, "Invalid Srpc Msg response packet"}
end
