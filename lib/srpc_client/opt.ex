defmodule SrpcClient.Opt do
  ## -----------------------------------------------------------------------------------------------
  ##  Return require configuration option or raise a fuss
  ## -----------------------------------------------------------------------------------------------
  def required(opt) when is_atom(opt) do
    unless value = Application.get_env(:srpc_client, opt) do
      raise SrpcClient.Error, message: "SrpcClient: Required configuration for #{opt} missing"
    end

    value
  end
end