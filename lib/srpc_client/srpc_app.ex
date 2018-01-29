defmodule SrpcClient.App do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  ## ===============================================================================================
  ##
  ##  Public
  ##
  ## ===============================================================================================
  def package(conn_info, method, path, body, headers) do
    req_info_data = req_info_data(method, path, headers, body)
    {nonce, data} = SrpcMsg.wrap(conn_info, req_info_data)

    case SrpcLib.encrypt(:origin_requester, conn_info, data) do
      {:ok, encrypted} ->
        {nonce, packet(conn_info, encrypted)}
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
    uri = URI.parse "http://host/#{path}"
    data = Poison.encode! %{method: method,
                             path: uri.path || "",
                             query: uri.query || "",
                             headers: headers}
    data_size = :erlang.byte_size(data)
    << data_size::size(16), data::binary, body::binary >>
  end

  defp packet(conn_info, data) do
    conn_id = conn_info[:conn_id]
    conn_id_size = :erlang.byte_size conn_id
    << SrpcMsg.app, conn_id_size, conn_id::binary, data::binary >>
  end

end
