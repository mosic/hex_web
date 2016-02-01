defmodule HexWeb.Package do
  use HexWeb.Web, :model

  @derive {Phoenix.Param, key: :name}

  @timestamps_opts [usec: true]

  schema "packages" do
    field :name, :string
    field :meta, :map
    timestamps

    has_many :releases, Release
    has_many :owners, PackageOwner
    has_many :downloads, PackageDownload
  end

  @elixir_names ~w(eex elixir ex_unit iex logger mix)
  @tool_names ~w(rebar rebar3 hex)
  @otp_names ~w(
    appmon asn1 common_test compiler cosEvent cosEventDomain cosFileTransfer
    cosNotification cosProperty cosTime cosTransactions crypto debugger
    dialyzer diameter edoc eldap erl_docgen erl_interface et eunit gs hipe
    ic inets jinterface kernel Makefile megaco mnesia observer odbc orber
    os_mon ose otp_mibs parsetools percept pman public_key reltool runtime_tools
    sasl snmp ssh ssl stdlib syntax_tools test_server toolbar tools tv typer
    webtool wx xmerl)

  @reserved_names @elixir_names ++ @otp_names ++ @tool_names

  @meta_types %{
    "maintainers"  => {:array, :string},
    "licenses"     => {:array, :string},
    "links"        => {:dict, :string, :string},
    "description"  => :string
  }

  @meta_fields Map.keys(@meta_types)
  @meta_fields_required ~w(description)

  defp validate_meta(changeset, field) do
    validate_change(changeset, field, fn _field, meta ->
      errors =
        Enum.flat_map(@meta_types, fn {sub_field, type} ->
          type(sub_field, Map.get(meta, sub_field), type)
        end)

      if errors == [],
          do: [],
        else: [{field, errors}]
    end)
  end

  defp validate_required_meta(changeset, field) do
    validate_change(changeset, field, fn _field, meta ->
      errors =
        Enum.flat_map(@meta_fields_required, fn field ->
          if Map.has_key?(meta, field) and is_present(meta[field]) do
            []
          else
            [{field, :missing}]
          end
        end)

      if errors == [],
          do: [],
        else: [{field, errors}]
    end)
  end

  defp is_present(string) when is_binary(string) do
    (string |> String.strip |> String.length) > 0
  end

  defp is_present(_string), do: true

  defp changeset(package, :create, params) do
    changeset(package, :update, params)
    |> validate_unique(:name, on: HexWeb.Repo)
  end

  # TODO: Drop support for contributors (maintainers released in 0.9.0, date TBD)

  defp changeset(package, :update, params) do
    cast(package, params, ~w(name meta), [])
    |> update_change(:meta, &rename_key(&1, "contributors", "maintainers"))
    |> update_change(:meta, &Map.take(&1, @meta_fields))
    |> validate_format(:name, ~r"^[a-z]\w*$")
    |> validate_exclusion(:name, @reserved_names)
    |> validate_required_meta(:meta)
    |> validate_meta(:meta)
  end

  defp rename_key(map, old_key, new_key) do
    case Map.fetch(map, old_key) do
      {:ok, value} ->
        map
        |> Map.delete(old_key)
        |> Map.put(new_key, value)
      :error ->
        map
    end
  end

  def create(owner, params) do
    changeset = changeset(%Package{}, :create, params)

    HexWeb.Repo.transaction(fn ->
      case HexWeb.Repo.insert(changeset) do
        {:ok, package} ->
          %PackageOwner{package_id: package.id, owner_id: owner.id}
          |> HexWeb.Repo.insert!

          {:ok, package}
        {:error, changeset} ->
          {:error, changeset.errors}
      end
    end)
    |> elem(1)
  end

  def update(package, params) do
    changeset = changeset(package, :update, params)

    case HexWeb.Repo.update(changeset) do
      {:ok, package} -> {:ok, package}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def get(name) do
    from(p in Package,
         where: p.name == ^name,
         limit: 1)
    |> HexWeb.Repo.one
  end

  def delete(package) do
    HexWeb.Repo.delete!(package)
  end

  def owners(package) do
    from(p in PackageOwner,
         where: p.package_id == ^package.id,
         join: u in User, on: u.id == p.owner_id,
         select: u)
    |> HexWeb.Repo.all
  end

  def owner?(package, user) do
    from(p in PackageOwner,
         where: p.package_id == ^package.id,
         where: p.owner_id == ^user.id,
         select: true)
    |> HexWeb.Repo.all
    |> Enum.any?
  end

  def last_owner?(package) do
    length(owners(package)) == 1
  end

  def add_owner(package, user) do
    %PackageOwner{package_id: package.id, owner_id: user.id}
    |> HexWeb.Repo.insert!
  end

  def delete_owner(package, user) do
    from(p in HexWeb.PackageOwner,
         where: p.package_id == ^package.id,
         where: p.owner_id == ^user.id)
    |> HexWeb.Repo.delete_all
  end

  def all(page, count, search \\ nil, sort \\ :name) do
    from(p in Package,
         preload: :downloads)
    |> sort(sort)
    |> HexWeb.Utils.paginate(page, count)
    |> search(search)
    |> HexWeb.Repo.all
  end

  def recent(count) do
    from(p in Package,
         order_by: [desc: p.inserted_at],
         limit: ^count,
         select: {p.name, p.inserted_at})
    |> HexWeb.Repo.all
  end

  def recent_full(count) do
    from(p in Package,
         order_by: [desc: p.inserted_at],
         limit: ^count)
    |> HexWeb.Repo.all
  end

  def count(search \\ nil) do
    from(p in Package, select: count(p.id))
    |> search(search)
    |> HexWeb.Repo.one!
  end

  def versions(package) do
    from(r in Release, where: r.package_id == ^package.id, select: r.version)
    |> HexWeb.Repo.all
  end

  defp search(query, nil) do
    query
  end

  defp search(query, search) do
    name_search = like_escape(search, ~r"(%|_)")
    if String.length(search) >= 3 do
      name_search = "%" <> name_search <> "%"
    end

    desc_search = String.replace(search, ~r"\s+", " | ")

    # without fragment("?::text", var.name) the gin_trgm_ops index will not be used
      from var in query,
    where: ilike(fragment("?::text", var.name), ^name_search) or
           fragment("to_tsvector('english', regexp_replace((?->'description')::text, '/', ' ')) @@ to_tsquery('english', ?)",
                    var.meta, ^desc_search)
  end

  defp like_escape(string, escape) do
    String.replace(string, escape, "\\\\\\1")
  end

  defp sort(query, :name) do
    from d in query, order_by: :name
  end

  defp sort(query, :inserted_at) do
    from d in query, order_by: [desc: :inserted_at, desc: :id]
  end

  defp sort(query, :updated_at) do
    from d in query, order_by: [desc: :updated_at, desc: :id]
  end

  defp sort(query, :downloads) do
    from p in query,
    left_join: d in PackageDownload, on: p.id == d.package_id and d.view == "all",
    order_by: [asc: is_nil(d.downloads), desc: d.downloads, desc: p.id]
  end

  defp sort(query, nil) do
    query
  end
end
