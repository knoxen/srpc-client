defmodule SrpcClient.Transport do
  @callback send(conn :: any(), srpc_packet :: binary()) :: {:ok, binary()} | {:error, binary()}
end
