defmodule SrpcClient.Opt do
  def srpc_file do
    opt = :srpc_file
    value = required(opt)
    unless is_binary(value), do: fail(opt, "must be a string: #{inspect(value)}")
    unless File.exists?(value), do: fail(opt, "file does not exist: #{value}")
    value
  end

  def transport do
    opt = :transport
    value = required(opt)
    unless is_atom(value), do: fail(opt, "must be a modulue: #{inspect(value)}")
    value
  end

  def reconnect do
    param(:reconnect) || false
  end

  def key_refresh do
    non_negative(:key_refresh)
  end

  def key_limit do
    non_negative(:key_limit)
  end

  defp non_negative(opt) when is_atom(opt) do
    value = param(opt) || 0
    unless is_integer(value), do: fail(opt, "must be an integer: #{inspect(value)}")
    if value < 0, do: fail(opt, "must be non-negative: #{value}")
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

  defp fail(opt, message) when is_atom(opt) and is_binary(message) do
    name = Atom.to_string(opt)
    raise(SrpcClient.Error, message: "SrpcClient config #{name} #{message}")
  end
end
