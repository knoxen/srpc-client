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

  def wrap(conn_info, true), do: wrap(conn_info, <<>>, true)
  def wrap(conn_info, false), do: wrap(conn_info, <<>>, false)

  def wrap(conn_info, data, encrypt \\ false) do
    time = :erlang.system_time(:second) + conn_info[:time_offset]
    time_data = <<time::size(@time_bits)>>

    nonce = :crypto.strong_rand_bytes(@nonce_size)
    nonce_data = <<@nonce_size, nonce::binary-size(@nonce_size)>>

    wrapped_data = <<@version, time_data::binary, nonce_data::binary, data::binary>>

    encrypt(conn_info, nonce, wrapped_data, encrypt)
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
  ## -----------------------------------------------------------------------------------------------
  ##  Encrypt data (or not)
  ## -----------------------------------------------------------------------------------------------
  defp encrypt(conn_info, nonce, data, true) do
    case SrpcLib.encrypt(:origin_requester, conn_info, data) do
      {:ok, encrypted_data} ->
        {nonce, encrypted_data}

      error ->
        error
    end
  end

  defp encrypt(_conn_info, nonce, data, false), do: {nonce, data}
end
