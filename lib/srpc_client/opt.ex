defmodule SrpcClient.Opt do
  
  def srpc_file do
    value = required(:srpc_file)
    unless is_string(value), do: fail("SrpcClient srpc_file must be a string: #{inspect(value)}")
    unless File.exists?(value), do: fail("SrpcClient srpc_file does not exist: #{value}")
    value
  end

  def transport do
    value = required(:transport)
    unless is_atom(value), do: fail("SrpcClient transport must be a modulue: #{inspect(value)}")
    value
  end

  def refresh do
    value = param(:refresh) || 0
    unless is_integer(value), do: fail("SrpcClient refresh must be an integer: #{inspect(value)}")
    if value < 0, do: fail("SrpcClient refresh value must be non-negative: #{value}")
    value
  end    

  ## -----------------------------------------------------------------------------------------------
  ##  Private
  ## -----------------------------------------------------------------------------------------------
  defp param(opt) do
    Application.get_env(:srpc_client, opt)
  end

  ## -----------------------------------------------------------------------------------------------
  ##  Return require configuration option or raise a fuss
  ## -----------------------------------------------------------------------------------------------
  defp required(opt) when is_atom(opt) do
    unless value = param(opt) do
      raise SrpcClient.Error, message: "SrpcClient missing configuration for #{opt}"
    end

    value
  end

  defp fail(message), do: raise SrpcClient.Error, message: message
  
end
