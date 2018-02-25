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

end
