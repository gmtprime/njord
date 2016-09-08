# Njord

[![Build Status](https://travis-ci.org/gmtprime/njord.svg?branch=master)](https://travis-ci.org/gmtprime/njord) [![Hex pm](http://img.shields.io/hexpm/v/njord.svg?style=flat)](https://hex.pm/packages/njord) [![hex.pm downloads](https://img.shields.io/hexpm/dt/njord.svg?style=flat)](https://hex.pm/packages/njord) [![Deps Status](https://beta.hexfaktor.org/badge/all/github/gmtprime/njord.svg)](https://beta.hexfaktor.org/github/gmtprime/njord) [![Inline docs](http://inch-ci.org/github/gmtprime/njord.svg?branch=master)](http://inch-ci.org/github/gmtprime/njord)

> Njörðr, god of the wind and the sea.

This library is a wrapper around `HTTPoison` to build client REST API libraries
as specifications.

```elixir
defmodule Github do
  use Njord

  @url "https://api.github.com"

  def valid_username(username) when is_binary(username), do: true
  def valid_username(_), do: false

  def process_url(%Njord{} = request, path, _state) do
    %Njord{request | url: @url <> path}
  end

  @doc """
  Calls the `GET https://api.github.com/users/:username` service. Requests the
  repositories from the `user`. Additionally, `HTTPoison` `options` can be
  provided.
  """
  defget :get_repos,
    [path: "/users/:user",
     arguments: [user: [type: :path_arg,
                        validation: fn user -> valid_username(user) end]]]
end
```

The previous example generates a module called `Github` with two functions:

  * `get_repos/1` that receives the user and returns the repositories from that
  user.

  * `get_repos/2` that receives the user and a list of options. This options
  are the same options passed to the functions in `HTTPoison` with the extra
  option `:state`. The state can be any Elixir term. This state is used in the
  functions that process the requests and the response.

The macro `defget` sends a `GET` request to the URL. For the other methods use
the macro that you need: `defget`, `defpost`, `defput`, `defdelete`, `defhead`,
`defpatch`, `defoptions`

```elixir
iex(1)> Github.get_repos("alexdesousa")
{:ok, %HTTPoison.Response{...}}
```

## Overriding functions

Like `HTTPoison`, `Njord` defines the following list of functions, all of
which can be overriden:

```elixir
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
```

## Installation

Just add it to your dependencies in your `mix.exs`:

```elixir
def deps do
  [{:njord, "~> 1.0.2"}]
end
```
