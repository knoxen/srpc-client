defmodule SrpcClient.Request do
  @type method :: :get | :post
  @type path :: binary
  @type body :: binary
  @type headers :: [{binary, binary}]

  @type t :: %__MODULE__{
          method: method,
          path: path,
          body: body,
          headers: headers
        }

  @enforce_keys [:method, :path]
  defstruct [:method, :path, body: "", headers: []]

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  alias :srpc_lib, as: SrpcLib

  def pack(conn, request) do
    case SrpcMsg.wrap_encrypt(conn, req_info_data(request)) do
      {:error, _} = error ->
        error

      {nonce, encrypted_data} ->
        packet = srpc_packet(conn, encrypted_data)
        {nonce, packet}
    end
  end

  def unpack(conn, nonce, encrypted_response) do
    case SrpcLib.decrypt(:origin_responder, conn, encrypted_response) do
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
  defp req_info_data(request) do
    uri = URI.parse("http://host#{request.path}")

    data =
      Poison.encode!(%{
        method: request.method,
        path: uri.path || "",
        query: uri.query || "",
        headers: request.headers
      })

    data_size = :erlang.byte_size(data)
    <<data_size::size(16), data::binary, request.body::binary>>
  end

  defp srpc_packet(conn, data) do
    conn_id = conn[:conn_id]
    conn_id_size = :erlang.byte_size(conn_id)
    <<SrpcMsg.app(), conn_id_size, conn_id::binary, data::binary>>
  end
end
