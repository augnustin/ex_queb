defmodule Test.Model do
  use Ecto.Schema
  schema "models" do
    field :name, :string
    field :age, :integer
    embeds_one(:embed, Test.Embed)
    belongs_to(:parent, Test.Parent)
    has_many(:children, Test.Children)
    has_many(:active_children, Test.Children, where: [is_active: true])
    many_to_many(:others, Test.Other, join_through: "model_others")

    timestamps()
  end
end

defmodule Test.Embed do
  use Ecto.Schema
  schema "models" do
    field :name, :string

    timestamps()
  end
end

defmodule Test.Noid do
  use Ecto.Schema
  @primary_key {:name, :string, []}
  schema "noids" do
    field :description, :string

    timestamps()
  end
end

defmodule Test.Noprimary do
  use Ecto.Schema
  @primary_key false
  schema "noprimarys" do
    field :index, :integer
    field :name, :string
    field :description, :string

    timestamps()
  end
end

defmodule Test.Children do
  use Ecto.Schema
  schema "children" do
    field :is_active, :boolean
    belongs_to(:model, Test.Model)
  end
end

defmodule Test.Parent do
  use Ecto.Schema
  schema "parents" do
    has_many(:children, Test.Model)
  end
end

defmodule Test.Other do
  use Ecto.Schema
  schema "others" do
    many_to_many(:models, Test.Model, join_through: "model_others")
  end
end

defmodule ExQuebTest do
  use ExUnit.Case
  doctest ExQueb
  import Ecto.Query
  require Logger

  test "no filter" do
    assert_equal ExQueb.filter(Test.Model, %{}), Test.Model
  end

  # %{blog_id_eq: "1", inserted_at_gte: nil, inserted_at_lte: nil, name_contains: nil, updated_at_gte: nil, updated_at_lte: nil}
  test "filters single field" do
    expected = where(Test.Model, [m], like(fragment("LOWER(?)", m.name), ^"%test%"))
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_contains: "Test"}}), expected
  end

  test "handles different default primary key" do
    query = from n in Test.Noid, preload: []
    expected = from n in Test.Noid, order_by: [desc: n.name]
    assert_equal ExQueb.build_order_bys(query, %{all: [preload: []]}, :index, [resource: "noids"]), expected
  end

  test "handles no primary key" do
    expected = from n in Test.Noprimary, order_by: [desc: n.index]
    query = from n in Test.Noprimary, preload: []
    opts = %{all: [preload: []]}
    assert_equal ExQueb.build_order_bys(query, opts, :index, [resource: "noprimarys"]), expected
  end

  test "handles default sort defined in opts" do
    expected = from n in Test.Noprimary, order_by: [asc: n.name]
    query = from n in Test.Noprimary, preload: []
    opts = %{all: [preload: []], index: [default_sort: [asc: :name]]}
    assert_equal ExQueb.build_order_bys(query, opts, :index, [resource: "noprimarys"]), expected
  end

  test "handles default_sort_order only for primary key id" do
    opts = %{all: [preload: []], index: [default_sort_order: :asc]}
    query = from n in Test.Model, preload: []
    expected = from n in Test.Model, order_by: [asc: n.id]
    assert_equal ExQueb.build_order_bys(query, opts, :index, [resource: "models"]), expected
  end

  test "handles default_sort_field only for no primary key" do
    opts = %{all: [preload: []], index: [default_sort_field: :name]}
    query = from n in Test.Noprimary, preload: []
    expected = from n in Test.Noprimary, order_by: [desc: n.name]
    assert_equal ExQueb.build_order_bys(query, opts, :index, [resource: "noprimarys"]), expected
  end

  test "integer filter greater than" do
    expected = where(Test.Model, [m], m.age > ^10)
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_gt: 10}}), expected
  end

  test "integer filter lower than" do
    expected = where(Test.Model, [m], m.age < ^10)
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_lt: 10}}), expected
  end

  test "integer filter lower than nil" do
    expected = Test.Model
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_lt: nil}}), expected
  end

  test "integer filter in single element list" do
    expected = where(Test.Model, [m], m.age in ^[10])
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_in: "10"}}), expected
  end

  test "integer filter in list" do
    expected = where(Test.Model, [m], m.age in ^[10, 11, 12])
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_in: "10,11,12"}}), expected
  end

  test "integer filter in list with spaces" do
    expected = where(Test.Model, [m], m.age in ^[10, 11, 12])
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_in: "10, 11 , 12"}}), expected
  end

  test "string filter contains" do
    expected = where(Test.Model, [m], like(fragment("LOWER(?)", m.name), ^"%test%"))
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_contains: "Test"}}), expected
  end

  test "string filter begins with" do
    expected = where(Test.Model, [m], like(fragment("LOWER(?)", m.name), ^"test%"))
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_begins_with: "Test"}}), expected
  end

  test "string filter ends with" do
    expected = where(Test.Model, [m], like(fragment("LOWER(?)", m.name), ^"%test"))
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_ends_with: "Test"}}), expected
  end

  test "string filter equals" do
    expected = where(Test.Model, [m], fragment("LOWER(?)", m.name) == fragment("LOWER(?)", ^"Test"))
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_equals: "Test"}}), expected
  end

  test "string filter equals nil" do
    expected = Test.Model
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_equals: nil}}), expected
  end

  test "string filter is not null" do
    expected = where(Test.Model, [m], not is_nil(m.name))
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_is: "not_null"}}), expected
  end

  test "string filter is null" do
    expected = where(Test.Model, [m], is_nil(m.name))
    assert_equal ExQueb.filter(Test.Model, %{q: %{name_is: "null"}}), expected
  end

  test "integer filter is not null" do
    expected = where(Test.Model, [m], not is_nil(m.age))
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_is: "not_null"}}), expected
  end

  test "integer filter is null" do
    expected = where(Test.Model, [m], is_nil(m.age))
    assert_equal ExQueb.filter(Test.Model, %{q: %{age_is: "null"}}), expected
  end

  test "date filter lower or equal than" do
    date = Date.utc_today
    expected = where(Test.Model, [m], m.inserted_at <= ^NaiveDateTime.from_iso8601!("#{Date.to_string(date)} 23:59:59"))
    assert_equal ExQueb.filter(Test.Model, %{q: %{inserted_at_lte: Date.to_string(date)}}), expected
  end

  test "date filter greater or equal than" do
    date = Date.utc_today
    expected = where(Test.Model, [m], m.inserted_at >= ^NaiveDateTime.from_iso8601!("#{Date.to_string(date)} 00:00:00"))
    assert_equal ExQueb.filter(Test.Model, %{q: %{inserted_at_gte: Date.to_string(date)}}), expected
  end

  test "embed filter is not null" do
    expected = where(Test.Model, [m], not is_nil(m.embed))
    assert_equal ExQueb.filter(Test.Model, %{q: %{embed_is: "not_null"}}), expected
  end

  test "embed filter is null" do
    expected = where(Test.Model, [m], is_nil(m.embed))
    assert_equal ExQueb.filter(Test.Model, %{q: %{embed_is: "null"}}), expected
  end

  test "children assoc filter not exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: not exists(from(a in Test.Children, where: a.model_id == parent_as(:query).id))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{children_is: "null"}}), expected
  end

  test "children assoc filter exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: exists(from(a in Test.Children, where: a.model_id == parent_as(:query).id))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{children_is: "not_null"}}), expected
  end

  test "active children assoc filter not exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: not exists(from(a in Test.Children, where: a.model_id == parent_as(:query).id and a.is_active == ^true))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{active_children_is: "null"}}), expected
  end

  test "active children assoc filter exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: exists(from(a in Test.Children, where: a.model_id == parent_as(:query).id and a.is_active == ^true))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{active_children_is: "not_null"}}), expected
  end

  test "parent assoc filter not exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: not exists(from(a in Test.Parent, where: a.id == parent_as(:query).parent_id))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{parent_is: "null"}}), expected
  end

  test "parent assoc filter exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: exists(from(a in Test.Parent, where: a.id == parent_as(:query).parent_id))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{parent_is: "not_null"}}), expected
  end

  test "many to many assoc filter not exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: not exists(from(
        o in Test.Other,
        join: mo in "model_others",
        on:
          o.id == mo.other_id and
          mo.model_id == parent_as(:query).id
        ))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{others_is: "null"}}), expected
  end

  test "many to many assoc filter exists" do
    expected = from(
      m in Test.Model,
      as: :query,
      where: exists(from(
        o in Test.Other,
        join: mo in "model_others",
        on:
          o.id == mo.other_id and
          mo.model_id == parent_as(:query).id
        ))
    )
    assert_equal ExQueb.filter(Test.Model, %{q: %{others_is: "not_null"}}), expected
  end

  def assert_equal(a, b) do
    assert inspect(a) == inspect(b)
  end
end
