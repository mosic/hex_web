defmodule HexWeb.API.UserControllerTest do
  use HexWeb.ConnCase

  alias HexWeb.User

  setup do
    User.create(%{username: "eric", email: "eric@mail.com", password: "eric"}, true)
    :ok
  end

  test "create user" do
    body = %{username: "name", email: "email@mail.com", password: "pass"}
    conn = conn()
           |> put_req_header("content-type", "application/json")
           |> post("api/users", Poison.encode!(body))

    assert conn.status == 201
    body = Poison.decode!(conn.resp_body)
    assert body["url"] =~ "/api/users/name"

    user = User.get(username: "name")
    assert user.email == "email@mail.com"
  end

  test "create user sends mails and requires confirmation" do
    body = %{username: "name", email: "create_user@mail.com", password: "pass"}
    conn = conn()
           |> put_req_header("content-type", "application/json")
           |> post("api/users", Poison.encode!(body))
    assert conn.status == 201
    user = User.get(username: "name")

    {subject, contents} = HexWeb.Email.Local.read("create_user@mail.com")
    assert subject =~ "Hex.pm"
    assert contents =~ "confirm?username=name&key=" <> user.confirmation_key

    meta = %{name: "ecto", version: "1.0.0", description: "Domain-specific language."}
    body = create_tar(meta, [])
    conn = conn()
           |> put_req_header("content-type", "application/octet-stream")
           |> put_req_header("authorization", key_for(user))
           |> post("api/packages/ecto/releases", body)

    assert conn.status == 403
    assert conn.resp_body =~ "account unconfirmed"

    conn = get(conn(), "password/confirm?username=name&key=" <> user.confirmation_key)
    assert conn.status == 200
    assert conn.resp_body =~ "Account confirmed"

    conn = conn()
           |> put_req_header("content-type", "application/octet-stream")
           |> put_req_header("authorization", key_for(user))
           |> post("api/packages/ecto/releases", body)

    assert conn.status == 201

    {subject, contents} = HexWeb.Email.Local.read("create_user@mail.com")
    assert subject =~ "Hex.pm"
    assert contents =~ "confirmed"
  end

  test "create user validates" do
    body = %{username: "name", password: "pass"}
    conn = conn()
           |> put_req_header("content-type", "application/json")
           |> post("api/users", Poison.encode!(body))

    assert conn.status == 422
    body = Poison.decode!(conn.resp_body)
    assert body["message"] == "Validation error(s)"
    assert body["errors"]["email"] == "can't be blank"
    refute User.get(username: "name")
  end

  test "get user" do
    conn = conn()
           |> put_req_header("content-type", "application/json")
           |> put_req_header("authorization", key_for("eric"))
           |> get("api/users/eric")

    assert conn.status == 200
    body = Poison.decode!(conn.resp_body)
    assert body["username"] == "eric"
    assert body["email"] == "eric@mail.com"
    refute body["password"]

    conn = get conn(), "api/users/eric"
    assert conn.status == 401
  end
end
