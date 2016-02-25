# Njord

> Njörðr, god of the wind and the sea.

[![Build Status](https://travis-ci.org/gmtprime/njord.svg?branch=master)](https://travis-ci.org/gmtprime/njord) [![Hex pm](http://img.shields.io/hexpm/v/njord.svg?style=flat)](https://hex.pm/packages/njord) [![hex.pm downloads](https://img.shields.io/hexpm/dt/njord.svg?style=flat)](https://hex.pm/packages/njord)

This library is a wrapper over `HTTPoison` to build client APIs. It provides a
series of macros that make easy to write a REST API client specification while
generating the corresponding functions of the API. Relies on `HTTPoison` to
do the actual request. To define a custom API specification just use
`Njord.Api` module as base.

```elixir
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
```

The above example shows how to create the functions `get_repos/1` and
`get_repos/2` (this one receives a list of options for `HTTPoison`) for the
endpoint `GET https://api.github.com/users/<username>`.

For synchronous requests:
```elixir
iex(1)> alias HTTPoison.Response, as: Response
iex(2)> Github.get_repos("alexdesousa")
{:ok, %HTTPoison.Response{...}}
```

For asynchronous requests:
```elixir
iex(3)> Github.get_repos("alexdesousa", stream_to: self())
{:ok, %HTTPoison.AsyncResponse{...}}
iex(4)> flush
%HTTPoison.AsyncStatus{...}
%HTTPoison.AsyncHeaders{...}
%HTTPoison.AsyncChunk{...}
...
%HTTPoison.AsyncChunk{...}
%HTTPoison.AsyncEnd{...}
```

## Overriding functions

Like `HTTPoison`, `Njord.Api` defines the following list of functions, all of
which can be overriden:

```elixir
# Processes the endpoint URL after the substitutions.
@spec process_url(Njord.Api.Request.t, String.t, term) :: Njord.Api.Request.t
def process_url(request, url, state)

# Processes the request headers.
@spec process_headers(Njord.Api.Request.t, [{binary, binary}], term) :: Njord.Api.Request.t
def process_headers(request, headers, state)

# Processes the request body.
@spec process_body(Njord.Api.Request.t, term, term) :: Njord.Api.Request.t
def process_body(request, body, state)
      
# Processes the response headers.
@spec process_response_headers(HTTPoison.Response.t, [{binary, binary}], term) :: HTTPoison.Response.t
def process_response_headers(response, headers, state)

# Processes the response body.
@spec process_response_body(HTTPoison.Response.t, String.t, term) :: HTTPoison.Response.t
def process_response_body(response, body, state)

# Processes the status code of the request.
@spec process_status_code(HTTPoison.Response.t, int, term) :: HTTPoison.Response.t
def process_status_code(response, status_code, state)
```

These functions are executed in the order they were listed.

## Options

When generating the specification of the endpoint, there are several options:

  * `name` - Name of the endpoint function.
  * `method` - Method to be used when doing the request.
  * `options` - List of options:
    + `:path` - Path of the endpoint. Use `:<name of the var>` to replace
      information it on the path i.e. `"/accounts/:login"` will expect a
      variable named `login` in the function arguments.
    + `:args` - Name of the variables of the endpoint function.
    + `:protocol` - Module where the protocol is defined.
    + `:state_getter` - Function to get or generate the state of every request.
    + `process_*` - Function to execute instead of the default.
      - `{module, function}` - It'll call the function `&module.function/3`
      - `:function` - It'll call the function `&__MODULE__.function/3`
      - `f when is_fun(f)` - It'll call the anonymous function `&(f.(&1, &2, &3))`.

      The following are the valid `process_*` functions:
      - `process_url` - Function to be used when processing the URL.
      - `process_headers` - Function to be used when processing the headers.
      - `process_body` - Function to be used when processing the body.
      - `process_response_headers` - Function to be used when processing the
        response headers.
      - `process_response_body` - Function to be used when processing the
        response body.
      - `process_status_code` - Function to be used when processing the
        status code of the response.

And when calling the genererated function there are other aditional options:
  * `:params` - Parameters of the HTTP request as a `Keyword` list.
  * `:body` - Body of the request. If in the definition of the endpoint there
    is an argument named `:body` this will have priority over the one in the
    options.
  * `:headers`-  Headers of the request. A list of tuples with the name of
    the header and its content.
  * `:state` - A state for the `process_*` functions.
  * `:state_getter` - Function to get or generate the state of the request.
  * Any other option available for `HTTPoison`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  * When available in `hex` Add njord to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:njord, "~> 0.1.1"}]
  end
  ```

  * If not available in `hex`:
      
  ```elixir
  def deps do
    [{:njord, github: "gmtprime/njord"}]
  end
  ```

  * Ensure njord can be used starting `HTTPoison`:

  ```elixir
  def application do
    [applications: [:httpoison]]
  end
  ```

