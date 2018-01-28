defmodule SrpcClient.Error do
  defexception message: "Srpc Client error"

  def reason({:error, reason}), do: inspect(reason)
end
