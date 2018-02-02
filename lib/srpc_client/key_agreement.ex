defmodule SrpcClient.KeyAgreement do
  alias SrpcClient.{LibKeyAgreement, UserKeyAgreement}

  ## CxTBD Optional data processing

  def lib(conn), do: LibKeyAgreement.connect(conn)

  def lib_user(conn, user_id, password) do
    conn
    |> LibKeyAgreement.connect()
    |> user(user_id, password)
  end

  def user(conn, user_id, password) do
    UserKeyAgreement.connect(conn, user_id, password)
  end
end
