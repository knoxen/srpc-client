defmodule SrpcClient.Util do
  ## -----------------------------------------------------------------------------------------------
  ##  Error term with string representation of the url and optional proxy in use.
  ## -----------------------------------------------------------------------------------------------
  def connection_refused do
    server = Application.get_env(:srpc_client, :server)

    proxy =
      if server[:proxy] do
        "via proxy #{server[:proxy]}"
      else
        ""
      end

    {:error, "Connection refused: http://#{server[:host]}:#{server[:port]} #{proxy}"}
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Return require configuration option or raise a fuss
  ## -----------------------------------------------------------------------------------------------
  def required_opt(opt) when is_atom(opt) do
    unless value = Application.get_env(:srpc_client, opt) do
      raise SrpcClient.Error, message: "SrpcClient: Required configuration for #{opt} missing"
    end

    value
  end

  def tag({:error, reason}, msg) do
    <<msg::binary, " error: ", reason::binary>>
  end

  def tag({:invalid, reason}, msg) do
    <<msg::binary, " invalid: ", reason::binary>>
  end
end
