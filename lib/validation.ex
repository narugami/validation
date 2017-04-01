defmodule Validation do
  @moduledoc """
  This module provides rails-like validations and strong parameters.
  Set `use Validation` in your model or web.ex.

  ## Examples
  ```
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

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only:
        [validates: 2, validate: 2, fetch: 2, fetch: 3, permit: 3, permit: 4]
      Module.register_attribute(__MODULE__, :validators, accumulate: :true)
      @before_compile unquote(__MODULE__)
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    validators_list = Module.get_attribute(env.module, :validators)
    quote do
      @doc false
      def validators, do: unquote(validators_list)
    end
  end

  @doc false
  @spec call_validators(struct, map, atom | list | map) :: struct
  defmacro call_validators(struct, field, validations) do
    Enum.reduce (if is_atom(validations), do: [validations], else: validations),
      struct, fn(validation, struct) ->
      case validation do
        {validator_name, args} ->
          quote do
            unquote(validator_name)(unquote(struct), unquote(field), unquote(args))
          end
        validator_name when is_atom(validator_name) ->
          quote do
            unquote(validator_name)(unquote(struct), unquote(field))
          end
      end
    end
  end

  @doc """
  Define required validations.
  A function which calls validators will be created.

  ## Examples
  ```
  validates :user_id, :foreign_key_constraint
  validates :sender_id, [:foreign_key_constraint]
  validates :body, validate_length: [min: 1, max: 80]
  ```
  """
  @spec validates(atom, atom | list | map) :: tuple
  defmacro validates(field, validations) do
    function_name = String.to_atom("validates_#{Atom.to_string(field)}")
    quote do
      @doc false
      @spec unquote(function_name)(struct) :: struct
      def unquote(function_name)(struct) do
        unquote(__MODULE__).call_validators(
          struct, unquote(field), unquote(validations))
      end
      @validators {unquote(field), &__MODULE__.unquote(function_name)/1}
    end
  end

  @doc """
  Validate fields.
  """
  @spec validate(struct, [atom]) :: tuple
  defmacro validate(struct, fields) do
    quote bind_quoted: [struct: struct, fields: fields] do
      Enum.reduce __MODULE__.validators, struct,
        fn({field, validator}, struct) ->
          if field in fields do
            validator.(struct)
          else
            struct
          end
        end
    end
  end

  @doc """
  Set required fields and validate fields.

  ## Examples
  ```
  def fetch_registration_changeset(struct, params \\ %{}) do
    struct
    |> fetch(~w(body user_id)a, ~w(price)a)
  end
  ```
  """
  @spec fetch(struct, [atom], [atom]) :: tuple
  defmacro fetch(struct, required_fields, optional_fields) do
    quote bind_quoted: [struct: struct,
      required_fields: required_fields, optional_fields: optional_fields] do
      struct
        |> Ecto.Changeset.validate_required(required_fields)
        |> validate(required_fields ++ optional_fields)
    end
  end

  @doc """
  Set required fields and validate fields.

  ## Examples
  ```
  def fetch_registration_changeset(struct, params \\ %{}) do
    struct
    |> fetch(~w(body user_id)a)
  end
  ```
  """
  @spec fetch(struct, [atom]) :: tuple
  defmacro fetch(struct, required_fields) do
    quote bind_quoted: [struct: struct, required_fields: required_fields] do
      fetch(struct, required_fields, [])
    end
  end

  @doc """
  Cast fields, set required fields and validate fields.

  ## Examples
  ```
  def registration_changeset(struct, params \\ %{}) do
    struct
    |> permit(params, ~w(body user_id)a, ~w(price)a)
  end
  ```
  """
  @spec permit(struct, map, [atom], [atom]) :: tuple
  defmacro permit(struct, params, required_fields, optional_fields) do
    quote bind_quoted: [struct: struct, params: params,
      required_fields: required_fields, optional_fields: optional_fields] do
      struct
        |> Ecto.Changeset.cast(params, required_fields ++ optional_fields)
        |> fetch(required_fields, optional_fields)
    end
  end

  @doc """
  Cast fields, set required fields and validate fields.

  ## Examples
  ```
  def registration_changeset(struct, params \\ %{}) do
    struct
    |> permit(params, ~w(body user_id price)a)
  end
  ```
  """
  @spec permit(struct, map, [atom]) :: tuple
  defmacro permit(struct, params, required_fields) do
    quote bind_quoted: [struct: struct, params: params,
      required_fields: required_fields] do
      permit(struct, params, required_fields, [])
    end
  end
end
