defmodule SrpcClient.AppRequest do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  alias SrpcClient.Util

  ## ===============================================================================================
  ##
  ##  Public
  ##
  ## ===============================================================================================
  def post(conn_info, srpc_request) do
    {nonce, packet} = package(conn_info, srpc_request)

    case Util.post(conn_info, packet) do
      {:ok, encrypted_response} ->
        unpackage(conn_info, nonce, encrypted_response)

      error ->
        error
    end
  end

  defp package(conn_info, srpc_request) do
    case SrpcMsg.wrap_encrypt(conn_info, req_info_data(srpc_request)) do
      {:error, _} = error ->
        error

      {nonce, encrypted_data} ->
        packet = srpc_packet(conn_info, encrypted_data)
        {nonce, packet}
    end
  end

  defp unpackage(conn_info, nonce, encrypted_response) do
    case SrpcLib.decrypt(:origin_responder, conn_info, encrypted_response) do
      {:ok, response_data} ->
        case SrpcMsg.unwrap(nonce, response_data) do
          {:ok, <<len::size(16), resp_info::binary-size(len), resp_data::binary>>} ->
            case Poison.decode(resp_info) do
              {:ok, %{"respCode" => 200}} ->
                {:ok, resp_data}

              {:ok, %{"respCode" => resp_code}} ->
                {:error, "Response code = #{resp_code}"}

              error ->
                error
            end

          {:ok, _} ->
            {:error, "Failed unpacking app response"}

          error ->
            error
        end

      error ->
        error
    end
  end

  ## ===============================================================================================
  ##
  ##  Private
  ##
  ## ===============================================================================================
  ## -----------------------------------------------------------------------------------------------
  ## -----------------------------------------------------------------------------------------------
  defp req_info_data(srpc_request) do
    
    uri = URI.parse("http://host#{srpc_request.path}")

    data =
      Poison.encode!(%{
        method: srpc_request.method,
        path: uri.path || "",
        query: uri.query || "",
        headers: srpc_request.headers
      })

    data_size = :erlang.byte_size(data)
    <<data_size::size(16), data::binary, srpc_request.body::binary>>
  end

  defp srpc_packet(conn_info, data) do
    conn_id = conn_info[:conn_id]
    conn_id_size = :erlang.byte_size(conn_id)
    <<SrpcMsg.app(), conn_id_size, conn_id::binary, data::binary>>
  end
end
