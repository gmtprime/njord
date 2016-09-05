defmodule Njord do
  @moduledoc """
  Njord behaviour.
  This library is a wrapper around `HTTPoison` to build client REST API
  libraries as specifications.

      defmodule Github do
        use Njord

        @url "https://api.github.com"

        def valid_username(username) when is_binary(username), do: true
        def valid_username(_), do: false

        def process_url(%Njord{} = request, path, _state) do
          %Njord{request | url: @url <> path}
        end

        defget :get_repos,
          [path: "/users/:user",
          arguments: [user: [type: :path_arg,
                             validation: fn x -> valid_username(x) end]]]
      end

  The previous example generates a module called `Github` with two functions:

    * `get_repos/1` that receives the user and returns the repositories from
    that user.

    * `get_repos/2` that receives the user and a list of options. This options
    are the same options passed to the functions in `HTTPoison` with the extra
    option `:state`. The state can be any Elixir term. This state is used in
    the functions that process the requests and the response.

  The macro `defget` sends a `GET` request to the URL. For the other methods
  use the macro that you need: `defget`, `defpost`, `defput`, `defdelete`,
  `defhead`, `defpatch`, `defoptions`

      iex(1)> Github.get_repos("alexdesousa")
      {:ok, %HTTPoison.Response{...}}

  ## Overriding functions

  Like `HTTPoison`, `Njord` defines the following list of functions, all of
  which can be overriden:

      alias HTTPoison.Response

      # Processes the endpoint URL after the substitutions.
      @spec process_url(Njord.t, String.t, term) :: Njord.t
      def process_url(request, url, state)

      # Processes the request headers.
      @spec process_headers(Njord.t, [{binary, binary}], term) :: Njord.t
      def process_headers(request, headers, state)

      # Processes the request body.
      @spec process_body(Njord.t, term, term) :: Njord.t
      def process_body(request, body, state)

      # Processes the response headers.
      @spec process_response_headers(name, Response.t, [{binary, binary}], term)
        :: Response.t
          when name: {function_name, arity}, function_name: atom, arity: integer
      def process_response_headers(name, response, headers, state)

      # Processes the response body.
      @spec process_response_body(name, Response.t, String.t, term)
        :: Response.t
          when name: {function_name, arity}, function_name: atom, arity: integer
      def process_response_body(name, response, body, state)

      # Processes the status code of the request.
      @spec process_status_code(name, Response.t, integer, term)
        :: Response.t
          when name: {function_name, arity}, function_name: atom, arity: integer
      def process_status_code(name, response, status_code, state)
  """
  alias HTTPoison.Response
  alias HTTPoison.AsyncResponse
  require Logger

  defstruct [:method, :url, :params, :body, :headers]
  @type method :: :get | :post | :put | :head | :patch | :delete | :options
  @type t :: %__MODULE__{
    method: method :: method,
    url: url :: binary,
    params: Keyword.t,
    body: Keyword.t,
    headers: headers :: list}
  alias __MODULE__, as: Njord

  defmodule ValidationError do
    @moduledoc """
    Validation error.
    """
    defexception message: "Validation error", data: []
  end

  #######################
  # Callback declaration.

  @doc """
  Processes the `url`. Receives the `request`, the `url` and the `state`. It
  should return the modified `request`.
  """
  @callback process_url(request :: Njord.t, url :: binary, state :: term) ::
    Njord.t

  @doc """
  Processes the request `body`. Receives the `request`, the `body` and the
  `state`. It should return the modified `request`.
  """
  @callback process_body(
    request :: Njord.t,
    body :: Keyword.t,
    state :: term
  ) :: Njord.t

  @doc """
  Processes the request `headers`. Receives the `request`, the `headers` and
  `state`. It should return the modified `request`.
  """
  @callback process_headers(
    request :: Njord.t,
    headers :: list,
    state :: term
  ) :: Njord.t

  @doc """
  Processes the response `status_code`. Receives the `function` tuple
  (`{name, arity}`), the `response`, the `status_code` and the `state`.
  """
  @callback process_status_code(
    response :: Response.t,
    function :: {name :: atom, arity :: integer},
    status_code :: term,
    state :: term) :: Njord.t

  @doc """
  Processes the response `body`. Receives the `function` tuple
  (`{name, arity}`), the `response`, the `body` and the `state`.
  """
  @callback process_response_body(
    response :: Response.t,
    function :: {name :: atom, arity :: integer},
    body :: term,
    state :: term) :: Njord.t

  @doc """
  Processes the response `headers`. Receives the `function` tuple
  (`{name, arity}`), the `response`, the `headers`, and the `state`.
  """
  @callback process_response_headers(
    response :: Response.t,
    function :: {name :: atom, arity :: integer},
    headers :: term,
    state :: term) :: Njord.t

  @doc """
  Basic definitions for the behaviour.
  """
  defmacro __using__(_) do
    quote do
      @behaviour Njord
      import Njord
      require Logger

      @doc false
      def process_url(%Njord{} = request, url, _state) do
        Njord.join_query(request, url)
      end

      @doc false
      def process_body(%Njord{} = request, body, _state) do
        %Njord{request | body: body}
      end

      @doc false
      def process_headers(%Njord{} = request, headers, _state) do
        %Njord{request | headers: headers}
      end

      @doc false
      def process_status_code(response, _, status_code, _state) do
        %Response{response | status_code: status_code}
      end

      @doc false
      def process_response_headers(response, _, headers, _state) do
        %Response{response | headers: headers}
      end

      @doc false
      def process_response_body(response, _, body, state) do
        %Response{response | body: body}
      end

      defoverridable [process_url: 3, process_body: 3, process_headers: 3,
                      process_status_code: 4, process_response_headers: 4,
                      process_response_body: 4]
    end
  end

  @doc """
  Generates a function to identified by a `name` call an API with the GET
  method. The list of `options` is the same as `defendpoint/3` macro.
  """
  defmacro defget(name, options \\ []), do:
    quote do: defendpoint(unquote(name), :get, unquote(options))

  @doc """
  Generates a function to identified by a `name` call an API with the POST
  method. The list of `options` is the same as `defendpoint/3` macro.
  """
  defmacro defpost(name, options \\ []), do:
    quote do: defendpoint(unquote(name), :post, unquote(options))

  @doc """
  Generates a function to identified by a `name` call an API with the PUT
  method. The list of `options` is the same as `defendpoint/3` macro.
  """
  defmacro defput(name, options \\ []), do:
    quote do: defendpoint(unquote(name), :put, unquote(options))

  @doc """
  Generates a function to identified by a `name` call an API with the DELETE
  method. The list of `options` is the same as `defendpoint/3` macro.
  """
  defmacro defdelete(name, options \\ []), do:
    quote do: defendpoint(unquote(name), :delete, unquote(options))

  @doc """
  Generates a function to identified by a `name` call an API with the HEAD
  method. The list of `options` is the same as `defendpoint/3` macro.
  """
  defmacro defhead(name, options \\ []), do:
    quote do: defendpoint(unquote(name), :head, unquote(options))

  @doc """
  Generates a function to identified by a `name` call an API with the PATCH
  method. The list of `options` is the same as `defendpoint/3` macro.
  """
  defmacro defpatch(name, options \\ []), do:
    quote do: defendpoint(unquote(name), :patch, unquote(options))

  @doc """
  Generates a function to identified by a `name` call an API with the OPTIONS
  method. The list of `options` is the same as `defendpoint/3` macro.
  """
  defmacro defoptions(name, options \\ []), do:
    quote do: defendpoint(unquote(name), :options, unquote(options))

  @doc """
  Generates a function to call an API endpoint.

  Args:
    * `name` - Name of the endpoint function.
    * `method` - Method to be used when doing the request. The possible values
    for the methods are `:get`, `:post`, `:put`, `:head`, `:patch` and
    `:options`.
    * `options` - List of options:
      - `:path` - Path to the endpoint. Use `:<name of the var>` to add the
      value of the variable as a path argument i.e. `"/accounts/:login"` will
      expect a variable named `login` in the endpoint function arguments.
      - `:protocol` - Module where the protocol is defined. By default is the
      module where this macro is called.
      - `:arguments` - List of arguments of the endpoint function. The
      arguments are defined as `name` or `{name, options}` where `name` is the
      name of the function argument and the `options` is a `Keyword` list with
      the following possible values:
        + `type` - Type of the argument. Possible values are `:path_arg`,
        `:arg` or `body`. By default, arguments are of type `:arg`.
        + `validation` - Validation function of arity of 1.

  The generated function has as many arguments as the `:arguments` option
  provided plus an optional list of `options`:
    * `:params` - URI query arguments of the request.
    * `:body` - Body of the request.
    * `:headers` - Headers of the request.
    * `:state` - The state of the request.
  """
  defmacro defendpoint(name, method, options \\ []) do
    arguments = Keyword.get(options, :arguments, [])
    fun_args = get_function_arguments(arguments)

    # Context
    function = {name, length(arguments) + 1}
    spec_args = get_clause_arguments(arguments)

    path = options |> Keyword.get(:path, "") |> get_path(fun_args)
    args = get_arguments(fun_args)
    body = get_body_arguments(fun_args)

    protocol = Keyword.get(options, :protocol, quote do: __MODULE__)

    quote do
      def unquote(name)(unquote_splicing(spec_args), options \\ []) do
        module = unquote(protocol)
        {state, options} = Keyword.pop(options, :state, nil)
        {params, options} = Keyword.pop(options, :params, [])
        {body, options} = Keyword.pop(options, :body, [])
        {headers, options} = Keyword.pop(options, :headers, [])

        request =
          %Njord{
            url: unquote(path),
            method: unquote(method),
            params: params |> Keyword.merge(unquote(args)),
            body: body |> Keyword.merge(unquote(body)),
            headers: headers
          }

        function = unquote(function)
        Njord.process(function, module, request, state, options)
      end
    end
  end

  @doc """
  Joins the params from the `request` as a query to the `url`.
  """
  def join_query(%Njord{params: []} = request, url) do
    %Njord{request | url: add_protocol(url)}
  end
  def join_query(%Njord{params: params} = request, url) do
    %Njord{request | url: add_protocol(url) <> "?" <> URI.encode_query(params)}
  end

  ##
  # Adds protocol to URL.
  defp add_protocol("http://" <> _ = url), do: url
  defp add_protocol("https://" <> _ = url), do: url
  defp add_protocol(url), do: "http://" <> url

  ###############################
  # Argument preparation helpers.

  ##
  # Gets the endpoint function cluse arguments from the `arguments`.
  defp get_clause_arguments(arguments) do
    for argument <- arguments do
      argument = if is_atom(argument), do: argument, else: elem(argument, 0)
      Macro.var(argument, Njord)
    end
  end

  ##
  # Gets the endpoint function arguments from the `arguments`.
  defp get_function_arguments(arguments) when is_list(arguments) do
    for argument <- arguments do
      if is_atom(argument) do
        {argument, [value: get_validated_var(argument, []), type: :arg]}
      else
        key = elem(argument, 0)
        options = elem(argument, 1)
        type = Keyword.get(options, :type, :arg)
        {key, [value: get_validated_var(key, options), type: type]}
      end
    end
  end

  ##
  # Gets arguments.
  defp get_arguments(fun_args) do
    get_arguments_by_type(fun_args, :arg)
  end

  ##
  # Gets body arguments.
  defp get_body_arguments(fun_args) do
    get_arguments_by_type(fun_args, :body)
  end

  ##
  # Gets path arguments
  defp get_path(path, fun_args) do
    path = split_path(path)
    path_args = get_arguments_by_type(fun_args, :path_arg)
    unused = unused_path_arguments(path, path_args)
    path =
      for word <- path do
        if is_atom(word), do: fetch_argument(word, path_args), else: word
      end
    quote do
      unquote(unused)
      unquote(path) |> Enum.join("/")
    end
  end

  ##
  # Warns about unused path arguments.
  defp unused_path_arguments(path, fun_args) do
    for {key, _} <- fun_args do
      if not Enum.member?(path, key) do
        quote bind_quoted: [key: key] do
          unquote(Njord.warn).("Path argument ':#{key}' not used.")
        end
      end
    end
  end

  ##
  # Gets arguments by type
  defp get_arguments_by_type(fun_args, type) do
    op = fn {name, options}, acc ->
      if options[:type] == type, do: [{name, options[:value]} | acc], else: acc
    end
    fun_args |> Enum.reduce([], op)
  end

  ##
  # Splits the path and adds an atom where the substitution should be made.
  defp split_path(path) do
    for word <- String.split(path, "/") do
      if Regex.match?(~r/:[^\/ :]+/, word) do
        word |> String.strip(?:) |> String.to_atom
      else
        word
      end
    end
  end

  ##
  # Fetch the argument of certain `type` from a list of `arguments` using a
  # `key` as the name of the variable.
  defp fetch_argument(key, arguments) do
    case Keyword.fetch(arguments, key) do
      :error ->
        quote bind_quoted: [key: key]do
          key = inspect(key)
          unquote(Njord.warn).("Path argument '#{key}' not found.")
          key
        end
      {:ok, value} ->
        quote bind_quoted: [value: value] do
          if is_binary(value), do: value, else: inspect(value)
        end
    end
  end

  ##
  # Gets the validated var identified by a `key` with a list of `options`.
  @doc false
  def get_validated_var(key, options) do
    var = Macro.var(key, Njord)
    function =
      case Keyword.get(options, :validation, nil) do
        nil ->
          quote do: fn _ -> true end
        {module, fun} ->
          quote do: &(apply(unquote(module), unquote(fun), [&1]))
        fun when is_atom(fun) ->
          quote do: &(apply(unquote(quote do: __MODULE__), unquote(fun), [&1]))
        fun ->
          quote do: &(unquote(fun).(&1))
      end
    validate_var(key, function, var)
  end

  ##
  # Validates variable `var` identified by `name` with a validation `function`
  # and returns the variable if valid. Returns a `ValidationError` otherwise.
  defp validate_var(name, function, var) do
    quote do
      var = unquote(var)
      function = unquote(function)
      if function.(var) do
        var
      else
        name = unquote(name)
        validation = unquote(Macro.to_string(function))
        metadata = [argument: name, function: validation, value: var]
        description = "Validation error"
        unquote(Njord.error).(description, metadata)
      end
    end
  end

  #####################
  # Warnings and errors

  ##
  # Creates a ValidationError.
  @doc false
  def error do
    quote do
      fn (description, metadata) ->
        env = unquote(quote do: __ENV__)
        filename = env.file |> Path.basename()
        line = inspect(env.line)
        message = "#{description} #{inspect metadata} (#{filename}:#{line})"
        Logger.error(message)
        raise ValidationError,
          message: message,
          data: [{:file, filename}, {:line, line} | metadata]
      end
    end
  end

  ##
  # Creates a warning.
  @doc false
  def warn do
    quote do
      fn (description) ->
        env = unquote(quote do: __ENV__)
        filename = env.file |> Path.basename()
        line = inspect(env.line)
        Logger.warn("#{description} (#{filename}:#{line})")
      end
    end
  end

  #####################
  # Request processing.

  @doc false
  def process(function, module, request, state, options) do
    case send_request(module, request, state, options) do
      {:ok, response} ->
        response = process_response(function, module, response, state)
        {:ok, response}
      other ->
        other
    end
  end

  ##
  # Sends the request.
  @doc false
  def send_request(module, %Njord{} = request, state, options) do
    http_module = Application.get_env(:njord, :http_module, HTTPoison)
    request =
      request
      |> module.process_url(request.url, state)
      |> module.process_headers(request.headers, state)
      |> module.process_body(request.body, state)
    args = [request.method,
            request.url,
            request.body,
            request.headers,
            options]
    Logger.debug("Sending request: #{inspect request}.")
    apply(http_module, :request, args)
  end

  ##
  # Process the response.
  @doc false
  def process_response(_, _, %AsyncResponse{} = response, _) do
    response
  end
  def process_response(
    function,
    module,
    %Response{
      headers: headers,
      body: body,
      status_code: status_code
    } = response,
    state
  ) do
    response
     |> module.process_response_headers(function, headers, state)
     |> module.process_response_body(function, body, state)
     |> module.process_status_code(function, status_code, state)
  end
end
