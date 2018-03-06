defmodule SrpcClient.Conn do
  @moduledoc """
  Documentation for SrpcClient.Connection
  """
  @type conn_id :: binary
  @type entity_id :: binary
  @type crypt_count :: integer
  @type crypt_key :: binary
  @type mono_time :: integer
  @type name :: binary
  @type sym_alg :: :aes256
  @type sha_alg :: :sha256
  @type type :: :lib | :user
  @type url :: binary

  @type t :: %__MODULE__{
          accessed: mono_time,
          conn_id: conn_id,
          created: mono_time,
          crypt_count: crypt_count,
          entity_id: entity_id,
          keyed: mono_time,
          name: name,
          pid: pid,
          reconnect_pw: binary | nil,
          req_sym_key: crypt_key,
          req_mac_key: crypt_key,
          resp_sym_key: crypt_key,
          resp_mac_key: crypt_key,
          sym_alg: sym_alg,
          sha_alg: sha_alg,
          type: type,
          url: url
        }

  @enforce_keys [
    :conn_id,
    :entity_id,
    :req_sym_key,
    :req_mac_key,
    :resp_sym_key,
    :resp_mac_key,
    :name,
    :type,
    :url
  ]
  defstruct @enforce_keys ++
              [sym_alg: :aes256, sha_alg: :sha256] ++
              [crypt_count: 0, time_offset: 0] ++
              [:accessed, :created, :keyed, :pid, :reconnect_pw]
end

defmodule SrpcClient.Conn.Info do
  @enforce_keys [:accessed, :count, :created, :keyed, :name]
  defstruct @enforce_keys
end
