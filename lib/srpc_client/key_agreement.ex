defmodule SrpcClient.KeyAgreement do
  alias SrpcClient.{LibKeyAgreement, UserKeyAgreement}

  ## CxTBD Optional data processing

  def lib(conn_info), do: LibKeyAgreement.connect(conn_info)

  def lib_user(conn_info, user_id, password) do
    conn_info
    |> LibKeyAgreement.connect()
    |> UserKeyAgreement.connect(user_id, password)
  end

end
