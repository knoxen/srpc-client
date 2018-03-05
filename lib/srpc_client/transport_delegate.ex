defmodule SrpcClient.TransportDelegate do
  alias SrpcClient.Opt

  def srpc(conn, packet) do
    conn |> Opt.transport().srpc(packet)
  end

  def app(conn, packet) do
    conn |> Opt.transport().app(packet)
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Error term with string representation of the url and optional proxy in use.
  ## -----------------------------------------------------------------------------------------------
  def refused do
    server = Application.get_env(:srpc_client, :server)

    proxy =
      if server[:proxy] do
        "via proxy #{server[:proxy]}"
      else
        ""
      end

    {:error, "Connection refused: http://#{server[:host]}:#{server[:port]} #{proxy}"}
  end
end
