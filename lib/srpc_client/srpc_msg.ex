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

  def wrap(conn_info, data, encrypt \\ false) do
    time = :erlang.system_time(:second) + conn_info[:time_offset]

    {nonce, nonce_data} = nonce_data()
    wrapped_data = <<@version, time::size(@time_bits), nonce_data::binary, data::binary>>
    
    {nonce, wrapped_data}
  end

  def unwrap(nonce, packet, return_time \\ false)

  def unwrap(
        nonce,
        <<@version, time::size(@time_bits), @nonce_size, nonce::binary-size(@nonce_size),
          data::binary>>,
        return_time
      ) do
    if return_time do
      {:ok, data, time}
    else
      {:ok, data}
    end
  end

  def unwrap(_nonce, _packet, _return_time), do: {:error, "Invalid Srpc Msg response packet"}

  defp nonce_data do
    nonce = :crypto.strong_rand_bytes(@nonce_size)
    {nonce, << @nonce_size, nonce::binary-size(@nonce_size) >>}
  end

end
