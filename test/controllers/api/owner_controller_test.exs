defmodule HexWeb.API.OwnerControllerTest do
  use HexWeb.ConnCase

  alias HexWeb.User
  alias HexWeb.Package
  alias HexWeb.Release

  setup do
    {:ok, user} = User.create(%{username: "eric", email: "eric@mail.com", password: "eric"}, true)
    {:ok, _}    = User.create(%{username: "jose", email: "jose@mail.com", password: "jose"}, true)
    {:ok, _}    = User.create(%{username: "other", email: "other@mail.com", password: "other"}, true)
    {:ok, pkg}  = Package.create(user, pkg_meta(%{name: "decimal", description: "Arbitrary precision decimal arithmetic for Elixir."}))
    {:ok, _}    = Package.create(user, pkg_meta(%{name: "postgrex", description: "Postgrex is awesome"}))
    {:ok, _}    = Release.create(pkg, rel_meta(%{version: "0.0.1", app: "decimal"}), "")
    :ok
  end

  test "get package owners" do
    conn = conn()
           |> put_req_header("authorization", key_for("eric"))
           |> get("api/packages/postgrex/owners")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert [%{"username" => "eric"}] = body

    package = Package.get("postgrex")
    user = User.get(username: "jose")
    Package.add_owner(package, user)

    conn = conn()
           |> put_req_header("authorization", key_for("eric"))
           |> get("api/packages/postgrex/owners")
    assert conn.status == 200

    body = Poison.decode!(conn.resp_body)
    assert [first, second] = body
    assert first["username"] in ["jose", "eric"]
    assert second["username"] in ["jose", "eric"]
  end

  test "get package owners authorizes" do
    conn = conn()
           |> put_req_header("authorization", key_for("other"))
           |> get("api/packages/postgrex/owners")
    assert conn.status == 403
  end

  test "check if user is package owner" do
    conn = conn()
           |> put_req_header("authorization", key_for("eric"))
           |> get("api/packages/postgrex/owners/eric@mail.com")
    assert conn.status == 204

    conn = conn()
           |> put_req_header("authorization", key_for("eric"))
           |> get("api/packages/postgrex/owners/jose@mail.com")
    assert conn.status == 404
  end

  test "check if user is package owner authorizes" do
    conn = conn()
           |> put_req_header("authorization", key_for("other"))
           |> get("api/packages/postgrex/owners/eric@mail.com")
    assert conn.status == 403
  end

  test "add package owner" do
    conn = conn()
           |> put_req_header("authorization", key_for("eric"))
           |> put("api/packages/postgrex/owners/jose%40mail.com")
    assert conn.status == 204

    package = Package.get("postgrex")
    assert [first, second] = Package.owners(package)
    assert first.username in ["jose", "eric"]
    assert second.username in ["jose", "eric"]
  end

  test "add package owner authorizes" do
    conn = conn()
           |> put_req_header("authorization", key_for("other"))
           |> put("api/packages/postgrex/owners/jose%40mail.com")
    assert conn.status == 403
  end

  test "delete package owner" do
    package = Package.get("postgrex")
    user = User.get(username: "jose")
    Package.add_owner(package, user)

    conn = conn()
           |> put_req_header("authorization", key_for("eric"))
           |> delete("api/packages/postgrex/owners/jose%40mail.com")
    assert conn.status == 204
    assert [%User{username: "eric"}] = Package.owners(package)

    conn = conn()
           |> put_req_header("authorization", key_for("eric"))
           |> delete("api/packages/postgrex/owners/jose%40mail.com")
    assert conn.status == 403
    assert [%User{username: "eric"}] = Package.owners(package)
  end

  test "delete package owner authorizes" do
    conn = conn()
           |> put_req_header("authorization", key_for("other"))
           |> delete("api/packages/postgrex/owners/eric%40mail.com")
    assert conn.status == 403
  end
end
