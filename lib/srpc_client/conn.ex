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
  @type req_mac_key :: binary
  @type resp_sym_key :: binary
  @type resp_mac_key :: binary
  @type sym_alg :: :aes256
  @type sha_alg :: :sha256
  # not required
  @type created :: integer
  @type accessed :: integer
  @type keyed :: integer
  @type crypt_count :: integer
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
    :req_mac_key,
    :resp_sym_key,
    :resp_mac_key
  ]
  defstruct @enforce_keys ++
              [sym_alg: :aes256, sha_alg: :sha256] ++
              [crypt_count: 0, time_offset: 0] ++ [:created, :accessed, :keyed]
end

defmodule SrpcClient.Conn.Info do
  @enforce_keys [:name, :created, :accessed, :keyed, :count]
  defstruct @enforce_keys
end
