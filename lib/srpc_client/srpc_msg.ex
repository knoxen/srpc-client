defmodule SrpcClient.Msg do
  use SrpcClient.Constant
  define(lib_exchange, 0x00)
  define(action, 0x10)
  define(app, 0xFF)

  alias :srpc_lib, as: SrpcLib

  @version 1
  @time_bits 32
  @nonce_size 10

  ## ===============================================================================================
  ##
  ##  Public
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ##  Wrap data for Sprc messaging
  ## -----------------------------------------------------------------------------------------------
  def wrap(conn_info), do: wrap(conn_info, <<>>)
  def wrap(conn_info, data) do
    time = :erlang.system_time(:second) + conn_info[:time_offset]
    time_data = <<time::size(@time_bits)>>
    nonce = :crypto.strong_rand_bytes(@nonce_size)
    nonce_data = <<@nonce_size, nonce::binary-size(@nonce_size)>>
    {nonce, <<@version, time_data::binary, nonce_data::binary, data::binary>>}
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Wrap data and encrypt for Sprc messaging
  ## -----------------------------------------------------------------------------------------------
  def wrap_encrypt(conn_info), do: wrap_encrypt(conn_info, <<>>)
  def wrap_encrypt(conn_info, data) do
    {nonce, wrapped_data} = wrap(conn_info, data)
    case SrpcLib.encrypt(:origin_requester, conn_info, wrapped_data) do
      {:ok, encrypted_data} ->
        {nonce, encrypted_data}
      error ->
        error
    end
  end

  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  
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

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
end
