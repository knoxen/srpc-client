defmodule SrpcClient.Poster do
  @callback post(conn :: any(), srpc_packet :: binary()) :: {:ok, binary()} | {:error, binary()}
end
