defmodule Njord.Api do
  @moduledoc """
  Provides a series of macros that make easy to write a REST API client
  specification while generating the corresponding functions of the api.
  Relies on `HTTPoison` to make the actual request. To define a custom API
  specification just use Njord.Api module as base.

      defmodule Github do
        use Njord.Api
        alias Njord.Api.Request, as: Request

        @url "https://api.github.com"

        def process_url(request, path, _state) do
          %Request{request | url: @url <> path}
        end

        defget :get_repos,
          path: "/users/:username",
          args: [:username]
      end

  The above example shows how to create the functions `get_repos/1` and
  `get_repos/2` (this one receives a list of options for `HTTPoison`) from the
  endpoint `GET https://api.github.com/users/<username>`.

      iex(1)> alias HTTPoison.Response, as: Response
      iex(2)> {:ok, %Response{} = response} = Github.get_repos("alexdesousa")
      iex(3)> Github.get_repos("alexdesousa", stream_to: self())

  ## Overriding functions

  Like `HTTPoison`, `Njord.Api` defines the following list of functions, all of
  which can be overriden:

      # Processes the endpoint URL after the substitutions.
      @spec process_url(Njord.Api.Request.t, String.t, term)
        :: Njord.Api.Request.t
      def process_url(request, url, state)

      # Processes the request headers.
      @spec process_headers(Njord.Api.Request.t, [{binary, binary}], term)
        :: Njord.Api.Request.t
      def process_headers(request, headers, state)

      # Processes the request body.
      @spec process_body(Njord.Api.Request.t, term, term)
        :: Njord.Api.Request.t
      def process_body(request, body, state)
      
      # Processes the response headers.
      @spec process_response_headers(HTTPoison.Response.t,
                                     [{binary, binary}],
                                     term)
        :: HTTPoison.Response.t
      def process_response_headers(response, headers, state)

      # Processes the response body.
      @spec process_response_body(HTTPoison.Response.t, String.t, term)
        :: HTTPoison.Response.t
      def process_response_body(response, body, state)

      # Processes the status code of the request.
      @spec process_status_code(HTTPoison.Response.t, int, term)
        :: HTTPoison.Response.t
      def process_status_code(response, status_code, state)

      # Processes the HTTP response (or error) after all the other `process_*`
      # functions.
      @spec process_http_response(HTTPoison.Response.t |
                                  HTTPoison.AsyncResponse.t |
                                  HTTPoison.Error.t, term) :: term
      def process_http_response(response, state)

  These functions are executed in the order they were listed.
  """

  defmodule Request do
    @moduledoc """
    Request information to API.
    """
    defstruct [:method, :url, :body, :headers]

    @type t :: %__MODULE__{method: method :: Atom.t,
                           url: url :: String.t,
                           body: body :: term,
                           headers: list}

    def new(method, url, body, headers) do
      %Request{method: method,
               url: url,
               body: body,
               headers: headers}
    end
  end

  alias HTTPoison.Response, as: Response
  alias HTTPoison.AsyncResponse, as: AsyncResponse
  alias HTTPoison.Error, as: Error

  defmodule ValidationError do
    defexception message: "Validation Error.", data: {:error, :validation}
  end

  defmacro __using__(_) do
    quote do
      import Njord.Api

      def process_url(%Request{} = request, url, _state) do
        case url |> String.slice(0, 8) |> String.downcase do
          "http://" <> _ -> %Request{request | url: url}
          "https://" <> _ -> %Request{request | url: url}
          _ -> %Request{request | url: "http://" <> url}
        end
      end

      def process_body(%Request{} = request, body, _state) do
        %Request{request | body: body}
      end

      def process_headers(%Request{} = request, headers, _state) do
        %Request{request | headers: headers}
      end

      def process_status_code(%Response{} = response, status_code, _state) do
        %Response{response | status_code: status_code}
      end

      def process_response_headers(%Response{} = response, headers, _state) do
        %Response{response | headers: headers}
      end

      def process_response_body(%Response{} = response, body, _state) do
        %Response{response | body: body}
      end

      def process_http_response(%Response{} = response, _state), do:
        {:ok, response}
      def process_http_response(%AsyncResponse{} = response, _state), do:
        {:ok, response}
      def process_http_response(%Error{} = error, _state), do:
        {:error, error}

      defoverridable [ process_url: 3, process_body: 3, process_headers: 3,
                       process_response_headers: 3, process_response_body: 3,
                       process_status_code: 3, process_http_response: 2] 
    end
  end

  ##
  # Splits the path, binding the variables already provided as arguments.
  #
  # i.e.
  #   args = [:login, :server]
  #   path = "/accounts/:login/"
  #   result = get_split_path([args: args, path: path])
  #   ^result = {["", "accounts", {:login, [], Njord.Api}, ""],
  #              [server: {:server, [], Njord.Api}],
  #              [{:login, [], Njord.Api}, {:server, [], Njord.Api}]}
  #
  # Args:
  #   * path - Path of the endpoint.
  #   * args - Arguments of the enpoint function.
  #
  # Returns:
  #   A tuple containing:
  #   { path,     # Split path
  #     not_used, # Keyword with the variables not replaced.
  #     body,     # Body arguments embedded in the function arguments.
  #     args}     # List of arguments of the endpoint function.
  defp _get_split_path(path, args) do
    margs = Enum.reduce(args, %{args: [], fun_args: [], body: []},
                        &_generate_argument/2)
    {path, not_used} = _split_path path, margs.args
    {path, not_used, margs.body, Enum.reverse(margs.fun_args)}
  end

  ##
  # Generates an argument and adds it to the accumulator.
  defp _generate_argument({name, opts}, acc) do
    validated_var = _get_validated_var name, opts
    case Keyword.get opts, :in_body, false do
      true ->
        %{acc | body: [{name, validated_var} | acc.body],
                fun_args: [Macro.var(name, Njord.Api) | acc.fun_args]}
      _ ->
        %{acc | args: [{name, validated_var} | acc.args],
                fun_args: [Macro.var(name, Njord.Api) | acc.fun_args]}
    end
  end

  defp _generate_argument(name, acc) do
    var = Macro.var(name, Njord.Api)
    %{acc | args: [{name, var} | acc.args],
            fun_args: [var | acc.fun_args]}
  end

  ##
  # Gets the variable with its validation.
  #
  # Args:
  #   * `name` - Name of the variable.
  #   * `opts` - Options for the variable.
  #
  # Returns:
  #   A quoted and maybe validated variable.
  defp _get_validated_var(name, opts) do
    function = case Keyword.get opts, :validation, nil do
      nil -> nil
      {module, fun} ->
        quote do: &(apply unquote(module), unquote(fun), [&1])
      fun when is_atom(fun) ->
        quote do: &(apply unquote(quote do: __MODULE__), unquote(fun), [&1])
      fun ->
        quote do: &(unquote(fun).(&1))
    end
    _generate_validated_var(name, function)
  end

  ##
  # Generates a variable with its validation function if it is provided.
  #
  # Args:
  #   * `name` - Variable name.
  #   * `function` - Function quoted definition.
  #
  # Returns:
  #   A quoted and maybe validated variable.
  defp _generate_validated_var(name, nil),  do:
    Macro.var(name, Njord.Api)

  defp _generate_validated_var(name, function) do
    var = Macro.var(name, Njord.Api)
    quote do
      var = unquote(var)
      function = unquote(function)
      if true == function.(var) do
        var
      else
        name = unquote(name)
        validation = unquote(Macro.to_string(function))
        raise ValidationError,
          message: """
            ValidationError:
            Error validating argument "#{name}" with:
              function: #{validation}
              received value: #{inspect var}
          """,
          data: {:error, %{validation: unquote(name),
                           function: validation,
                           value: var}}
      end
    end 
  end

  ##
  # Splits the path into a list and replaces the variables in the arguments.
  #
  # Args:
  #   * path - String path.
  #   * margs - Keyword with the variables to replace.
  #
  # Returns:
  #   A tuple containing:
  #   {path,     # Split path.
  #    not_used} # Keyword with the variables not used.
  defp _split_path(path, margs) do
    path
    |> String.split("/")
    |> Enum.reduce({[], margs}, &_substitute_macro_var/2)
    |> (fn({path, not_used}) -> {Enum.reverse(path), not_used} end).()
  end

  ##
  # Replaces an atom by a macro variable in the `path` if the `word` is found
  # in the `not_used` keyword.
  defp _substitute_macro_var(word, {path, not_used}) do
    if Regex.match? ~r/:[^\/ :]+/, word do
      word = String.strip(word, ?:) |> String.to_atom
      {var, not_used} = Keyword.pop not_used, word, word
      {[var | path], not_used}
    else
      {[word | path], not_used}
    end
  end

  ##
  # Get path
  defp _get_path(options), do:
    Keyword.get options, :path, "/"

  ##
  # Get function arguements.
  defp _get_function_arguments(options), do:
    Keyword.get options, :args, []

  ##
  # Gets the process functions.
  defp _get_process_functions(options) do 
    module = Keyword.get options, :protocol, quote do: __MODULE__
    [{:process_url, 3}, {:process_headers, 3}, {:process_body, 3},
     {:process_response_headers, 3}, {:process_response_body, 3},
     {:process_status_code, 3}, {:process_http_response, 2}]
    |> Enum.map(
        fn ({name, arity}) ->
          fun = Keyword.get options, name, nil
          quoted_function = _get_process_function(module, name, arity, fun)
          {name, quoted_function}
        end)
    |> Map.new
  end

  ##
  # TODO: Implement with currying
  # Gets a single quoted function.
  defp _get_process_function(module, name, 3, nil), do:
    quote do: &(apply unquote(module), unquote(name), [&1, &2, &3])
  defp _get_process_function(_, _, 3, {module, fun}), do:
    quote do: &(apply unquote(module), unquote(fun), [&1, &2, &3])
  defp _get_process_function(_, _, 3, fun) when is_atom(fun), do:
    quote do: &(apply unquote(quote do: __MODULE__), unquote(fun), [&1, &2, &3])
  defp _get_process_function(_, _, 3, fun), do:
    quote do: &(unquote(fun).(&1, &2, &3))
  
  defp _get_process_function(module, name, 2, nil), do:
    quote do: &(apply unquote(module), unquote(name), [&1, &2])
  defp _get_process_function(_, _, 2, {module, fun}), do:
    quote do: &(apply unquote(module), unquote(fun), [&1, &2])
  defp _get_process_function(_, _, 2, fun) when is_atom(fun), do:
    quote do: &(apply unquote(quote do: __MODULE__), unquote(fun), [&1, &2])
  defp _get_process_function(_, _, 2, fun), do:
    quote do: &(unquote(fun).(&1, &2))

  ##
  # Gets state
  defp _get_state(options) do
    case Keyword.get options, :state_getter, nil do
      nil ->
        quote do
          case Keyword.pop opts, :state_getter, nil do
            {nil, opts} ->
              Keyword.pop opts, :state, nil
            {state_getter, opts} ->
              {state_getter.(), opts}
          end
        end
      state_getter ->
        quote do: {unquote(state_getter).(), opts}
    end
  end

  ##
  # Gets the request body type. It can be :json, :query or :binary. It is :json
  # by default.
  defp _get_request_body_type(options) do
    case Keyword.get options, :request_body_type, :json do
      :json -> :json
      :query -> :query
      :binary -> :binary
      type ->
        raise ValidationError,
          message: "Invalid request body type: #{inspect type}",
          data: nil
    end
  end

  @doc """
  Generates a function to call an endpoint.

  Args:
    * `name` - Name of the endpoint function.
    * `method` - Method to be used when doing the request.
    * `options` - List of options:
      + `:path` - Path of the endpoint. Use `:<name of the var>` to replace
        information it on the path i.e. `"/accounts/:login"` will expect a
        variable named `login` in the function arguments.
      + `:args` - List of name of the variables of the endpoint function. The
        names are defined as follows:
        - `{name, opts}`: Name of the variable and list of options.
          * `in_body: boolean`: To pass the variable to a body `Map` or not.
          * `validation: function()`: Function of arity 1 to validate the
          function argument. It receives the argument and returns a boolean.
        - `name when is_atom(name)`: Name of the argument. No options. By
          default goes to the URL parameters or path arguments.
      + `:protocol` - Module where the protocol is defined. By default is
        the current module.
      + `:state_getter` - Function to get or generate the state of every
        request.
      + `:request_body_type` - Whether the body is a `:json`, `:query` string
        or `:binary`.
      + `process_*` - Function to execute instead of the default.
        * `{module, function}` - Executes the function `&module.function/3`
        * `:function` - Executes the function `__MODULE__.function/3`
        * `function()` - Closure of a function with arity 3.
        
        The following are the valid `process_*` functions:
        * `process_url` - Function to be used when processing the URL.
        * `process_headers` - Function to be used when processing the headers.
        * `process_body` - Function to be used when processing the body.
        * `process_response_headers` - Function to be used when processing the
          response headers.
        * `process_response_body` - Function to be used when processing the
          response body.
        * `process_status_code` - Function to be used when processing the
          status code of the response.

      There's an exception for the function `process_http_response`. This
      function has arity equal to 2. This function is used to process the HTTP
      response after it has been processed by all the other `process_*`
      functions. It receives the HTTP response (or error) and the state.

  Options when calling the genererated function:
    * `:params` - Parameters of the HTTP request as a `Keyword` list.
    * `:body` - Body of the request. If in the definition of the endpoint there
      is an argument named `:body` this will have priority over the one in the
      options.
    * `:headers`-  Headers of the request. A list of tuples with the name of
      the header and its content.
    * `:state` - A state for the `process_*` functions.
    * `:state_getter` - Function to get or generate the state of the request.
  
  Any other option available in `HTTPoison`.

  Returns:
    Endpoint function definition.
  """
  defmacro defendpoint(name, method, options \\ []) do
    path = _get_path options
    args = _get_function_arguments options
    functions = _get_process_functions options
    {path, not_used, body, args} = _get_split_path path, args
    state = _get_state options
    request_body_type = _get_request_body_type options
    quote do
      def unquote(name)(unquote_splicing(args), opts \\ []) do
        # Get path.
        path = unquote(path)
        not_used = unquote(not_used)
        {path, opts} = build_path(path, not_used, opts)

        # Get body.
        embedded_body = unquote(body) |> Map.new
        {body, opts} = build_body(not_used, opts)
        body = if embedded_body != %{} do
          cond do
            is_map(body) ->
              Map.merge(body, embedded_body)
            is_list(body) ->
              body = body |> Map.new
              Map.merge(body, embedded_body)
            body == "" ->
              embedded_body
            true ->
              Map.put embedded_body, :body, body
          end
        else
          body
        end

        # Get headers.
        {headers, opts} = build_headers(opts)

        # Get state.
        {state, opts} = unquote(state)

        # Build request.
        method = unquote(method)
        req = Request.new method, path, body, headers

        # Process
        process_url = unquote(functions.process_url)
        process_headers = unquote(functions.process_headers)
        process_body = unquote(functions.process_body)
        process_response_headers = unquote(functions.process_response_headers)
        process_response_body = unquote(functions.process_response_body)
        process_status_code = unquote(functions.process_status_code)
        process_http_response = unquote(functions.process_http_response)
        request_body_type = unquote(request_body_type)
        result = req
                 |> process_url.(path, state)
                 |> process_headers.(headers, state)
                 |> process_body.(body, state)
                 |> request(request_body_type, opts)

        processed = case result do
          {:ok, %Response{} = response} ->
            result = response
                     |> process_response_headers.(response.headers, state)
                     |> process_response_body.(response.body, state)
                     |> process_status_code.(response.status_code, state)

            %Response{body: result.body, headers: result.headers,
                      status_code: result.status_code}
          {:ok, %AsyncResponse{} = response} -> response
          {:error, error} -> error
        end
        process_http_response.(processed, state)
      end
    end
  end

  @doc """
  Generates a function to call a GET endpoint.

  Args:
    * `name` - Name of the function.
    * `opts` - Options to create the endpoint. Same as `defendpoint`.

  Returns:
    Function definition.
  """
  defmacro defget(name, opts \\ []), do:
    quote do: defendpoint(unquote(name), :get, unquote(opts))

  @doc """
  Generates a function to call a POST endpoint.

  Args:
    * `name` - Name of the function.
    * `opts` - Options to create the endpoint. Same as `defendpoint`.

  Returns:
    Function definition.
  """
  defmacro defpost(name, opts \\ []), do:
    quote do: defendpoint(unquote(name), :post, unquote(opts))

  @doc """
  Generates a function to call a PUT endpoint.

  Args:
    * `name` - Name of the function.
    * `opts` - Options to create the endpoint. Same as `defendpoint`.

  Returns:
    Function definition.
  """
  defmacro defput(name, opts \\ []), do:
    quote do: defendpoint(unquote(name), :put, unquote(opts))

  @doc """
  Generates a function to call a HEAD endpoint.

  Args:
    * `name` - Name of the function.
    * `opts` - Options to create the endpoint. Same as `defendpoint`.

  Returns:
    Function definition.
  """
  defmacro defhead(name, opts \\ []), do:
    quote do: defendpoint(unquote(name), :head, unquote(opts))

  @doc """
  Generates a function to call a PATCH endpoint.

  Args:
    * `name` - Name of the function.
    * `opts` - Options to create the endpoint. Same as `defendpoint`.

  Returns:
    Function definition.
  """
  defmacro defpatch(name, opts \\ []), do:
    quote do: defendpoint(unquote(name), :patch, unquote(opts))

  @doc """
  Generates a function to call a DELETE endpoint.

  Args:
    * `name` - Name of the function.
    * `opts` - Options to create the endpoint. Same as `defendpoint`.

  Returns:
    Function definition.
  """
  defmacro defdelete(name, opts \\ []), do:
    quote do: defendpoint(unquote(name), :delete, unquote(opts))

  @doc """
  Generates a function to call an OPTIONS endpoint.

  Args:
    * `name` - Name of the function.
    * `opts` - Options to create the endpoint. Same as `defendpoint`.

  Returns:
    Function definition.
  """
  defmacro defoptions(name, opts \\ []), do:
    quote do: defendpoint(unquote(name), :options, unquote(opts))

  @doc false
  def build_path(path, not_used, options) do
    {arguments, options} = Keyword.pop options, :params, []
    {_, not_used} = Keyword.pop not_used, :body, nil
    arguments = Keyword.merge arguments, not_used
    path = Enum.reduce(path, {[], arguments},
      fn(word, {path, arguments}) when is_atom(word) -> 
          {word, arguments} = Keyword.pop arguments, word, to_string(word)
          {[to_string(word) | path], arguments}
        (word, {path, arguments}) ->
          {[word | path], arguments}
      end)
    |> (fn({path, []}) ->
            Enum.reverse(path)
            |> Enum.join("/")
          ({path, arguments}) ->
            Enum.reverse(path)
            |> Enum.join("/")
            |> (&(&1 <> "?" <> URI.encode_query(arguments))).()
        end).()
    {path, options}
  end

  @doc false
  def build_body(not_used, options) do
    case Keyword.get not_used, :body, nil do
      nil ->
        Keyword.pop options, :body, ""
      body ->
        {_, options} = Keyword.pop options, :body, nil
        {body, options}
    end
  end

  @doc false
  def build_headers(options), do:
    Keyword.pop options, :headers, []

  @doc false
  def request(%Request{} = request, :json, opts), do:
    request(%Request{request | body: Poison.encode!(request.body)}, opts)

  def request(%Request{} = request, :query, opts), do:
    request(%Request{request | body: URI.encode_query(request.body)}, opts)

  def request(%Request{} = request, _, opts), do:
    request(request, opts)

  @doc false
  def request(%Request{} = request, opts) do
    args = [request.method,
            request.url,
            request.body,
            request.headers,
            opts]
    apply(HTTPoison, :request, args)
  end
end
