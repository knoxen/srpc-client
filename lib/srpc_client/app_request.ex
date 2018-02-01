defmodule SrpcClient.AppRequest do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  alias SrpcClient.Util

  require Logger

  ## ===============================================================================================
  ##
  ##  Public
  ##
  ## ===============================================================================================
  def post(conn_info, params) do
    {nonce, packet} = package(conn_info, params)

    case Util.post(conn_info[:url], packet) do
      {:ok, encrypted_response} ->
        unpackage(conn_info, nonce, encrypted_response)

      error ->
        error
    end
  end

  defp package(conn_info, {method, path, body, headers}) do
    req_info_data = req_info_data(method, path, headers, body)
    {nonce, data} = SrpcMsg.wrap(conn_info, req_info_data)

    case SrpcLib.encrypt(:origin_requester, conn_info, data) do
      {:ok, encrypted} ->
        {nonce, srpc_packet(conn_info, encrypted)}

      error ->
        error
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
  defp req_info_data(method, path, headers, body) do
    uri = URI.parse("http://host#{path}")

    data =
      Poison.encode!(%{
        method: method,
        path: uri.path || "",
        query: uri.query || "",
        headers: headers
      })

    data_size = :erlang.byte_size(data)
    <<data_size::size(16), data::binary, body::binary>>
  end

  defp srpc_packet(conn_info, data) do
    conn_id = conn_info[:conn_id]
    conn_id_size = :erlang.byte_size(conn_id)
    <<SrpcMsg.app(), conn_id_size, conn_id::binary, data::binary>>
  end
end