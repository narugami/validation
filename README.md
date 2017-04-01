# Validation
Rails-like validations and strong parameters in Phoenix/Elixir.  
[WIP] Tests don't exist :-( but it works correctly.

## Examples
```elixir
defmodule Hoge.User do
  use Hoge.Web, :model
  use Validation

  schema "users" do
    field :name, :string
    timestamps()
  end

  validates :name, validate_length: [min: 1, max: 20]

  def changeset(struct, params \\ %{}) do
    struct
    |> permit(params, [:name])
  end
end
```

## TODO
* Tests
