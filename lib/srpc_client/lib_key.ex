defmodule SrpcClient.LibKey do
  alias :srpc_lib, as: SrpcLib

  require SrpcClient.Msg
  alias SrpcClient.Msg, as: SrpcMsg

  require SrpcClient.Action
  alias SrpcClient.Action, as: SrpcAction

  require Logger

  def agreement(conn_state) do
    host = conn_state[:host]
    port = conn_state[:port]
    srpc_url = "http://#{host}:#{port}/"

    case lib_exchange(srpc_url) do
      {:ok, conn_info} ->
        case lib_confirm(conn_info) do
          {:ok, conn_info} ->
            conn_state ++ [conn_info: conn_info]

          error ->
            Logger.debug("lib confirm error: #{inspect(error)}")
            error
        end

      error ->
        Logger.debug("lib exchange error: #{inspect(error)}")
        error
    end
  end

  defp lib_exchange(srpc_url) do
    {client_keys, exch_req} = SrpcLib.create_lib_key_exchange_request(SrpcLib.srpc_id())

    case srpc_lib_exchange(srpc_url, exch_req) do
      {:ok, exch_resp} ->
        case SrpcLib.process_lib_key_exchange_response(client_keys, exch_resp) do
          {:ok, conn_info} ->
            {:ok, conn_info |> Map.merge(%{srpc_url: srpc_url, time_offset: 0})}

          error ->
            error
        end

      error ->
        Logger.error("LibKey.lib_exchange error: #{inspect(error)}")
        error
    end
  end

  defp lib_confirm(conn_info) do
    {nonce, client_data} = SrpcMsg.wrap(conn_info)
    confirm_request = SrpcLib.create_lib_key_confirm_request(conn_info, client_data)

    case SrpcAction.packet(conn_info, SrpcAction.lib_confirm(), confirm_request) do
      {:ok, request_packet} ->
        start_time = :erlang.system_time(:seconds)

        case srpc_post(conn_info[:srpc_url], request_packet) do
          {:ok, encrypted_packet} ->
            delta = :erlang.system_time(:seconds) - start_time

            case SrpcLib.decrypt(:origin_server, conn_info, encrypted_packet) do
              {:ok, confirm_response} ->
                case SrpcLib.process_lib_key_confirm_response(conn_info, confirm_response) do
                  {:ok, confirm_data} ->
                    case SrpcMsg.unwrap(conn_info, nonce, confirm_data, false) do
                      {:ok, conn_info, _data} ->
                        their_time = conn_info[:time_offset]

                        time_offset =
                          their_time - :erlang.system_time(:seconds) - trunc(delta / 2)

                        {:ok,
                         conn_info
                         |> Map.put(:time_offset, time_offset)
                         |> :srpc_util.remove_keys([:exch_public_key, :exch_key_pair, :exch_hash])}

                      error ->
                        error
                    end

                  error ->
                    error
                end

              error ->
                error
            end

          error ->
            Logger.error("LibKey.lib_confirm error: #{inspect(error)}")
            error
        end

      error ->
        error
    end
  end

  defp srpc_lib_exchange(srpc_url, exch_req) do
    srpc_post(srpc_url, <<SrpcMsg.lib_exchange(), exch_req::binary>>)
  end

  defp srpc_post(srpc_url, body) do
    case HTTPoison.post(srpc_url, body, [], proxy: {"localhost.charlesproxy.com", 8888}) do
      {:ok, %{:body => body, :status_code => 200}} ->
        {:ok, body}

      {:ok, %{:status_code => status_code}} ->
        {:error, "Status code = #{status_code}"}

      error ->
        error
    end
  end
end
