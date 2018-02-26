defmodule SrpcClient.Conn do
  @moduledoc """
  Documentation for SrpcClient.Connection
  """
  # required
  @type type :: :lib | :user
  @type name :: binary
  @type url :: binary
  @type conn_id :: binary
  @type entity_id :: binary
  @type req_sym_key :: binary
  @type req_hmac_key :: binary
  @type resp_sym_key :: binary
  @type resp_hmac_key :: binary
  @type sym_alg :: :aes256
  @type sha_alg :: :sha256
  # not required
  @type created :: integer
  @type accessed :: integer
  @type keyed :: integer
  @type time_offset :: integer

  @type t :: %__MODULE__{
          type: type,
          name: name,
          url: url
        }

  @enforce_keys [
    :type,
    :name,
    :url,
    :conn_id,
    :entity_id,
    :req_sym_key,
    :req_hmac_key,
    :resp_sym_key,
    :resp_hmac_key
  ]
  defstruct @enforce_keys ++
              [sym_alg: :aes256, sha_alg: :sha256] ++ [:created, :accessed, :keyed, :time_offset]
end

defmodule SrpcClient.Conn.Info do
  @enforce_keys [:name, :created, :accessed, :keyed]
  defstruct @enforce_keys
end
