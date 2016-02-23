defmodule Njord.ApiTest do
  use ExUnit.Case, async: true

  defmodule TestApi do
    use Njord.Api

    def process_body(request, body, nil) do
      %Njord.Api.Request{request | body: body}
    end
    
    def process_body(request, body, state) do
      send state.pid, state.type
      %Njord.Api.Request{request | body: body}
    end

    # Endpoint without path.
    defendpoint :ep_without_path, :get

    # Endpoint without arguments.
    defendpoint :ep_without_args, :get,
      path: "njord-rocks.com/get"

    # Endpoint with a single path argument.
    defendpoint :ep_with_path_arg, :get,
      path: "njord-rocks.com/get/:arg",
      args: [:arg]

    # Endpoint with path arguments.
    defendpoint :ep_with_path_args, :get,
      path: "njord-rocks.com/get/:arg0/:arg1",
      args: [:arg0, :arg1]

    # Endpoint with path arguments and parameters.
    defendpoint :ep_with_path_args_and_params, :get,
      path: "njord-rocks.com/get/:arg0/:arg1",
      args: [:arg0, :arg1, :arg2, :arg3]

    # Endpoint with body.
    defendpoint :ep_with_body, :post,
      path: "njord-rocks.com/post/:arg",
      args: [:arg, :body]

    # Endpoint with params.
    defendpoint :ep_with_params, :get,
      path: "njord-rocks.com/get/:arg0",
      args: [:arg0, :arg1]

    # Endpoint with default state generator.
    defendpoint :ep_with_state, :get,
      state_getter: fn -> %{pid: self(), type: :default_state} end

    # GET endpoint
    defget :get,
      path: "njord-rocks.com/get"

    # POST endpoint
    defpost :post,
      path: "njord-rocks.com/get"

    # PUT endpoint
    defput :put,
      path: "njord-rocks.com/put"

    # HEAD endpoint
    defhead :head,
      path: "njord-rocks.com/head"

    # PATCH endpoint
    defpatch :patch,
      path: "njord-rocks.com/patch"

    # DELETE endpoint
    defdelete :delete,
      path: "njord-rocks.com/delete"

    # OPTIONS endpoint
    defoptions :options,
      path: "njord-rocks.com/options"
  end

  setup do
    pid = self()
    :meck.new(Njord.Api, [:passthrough])
    :meck.expect(Njord.Api, :request,
      fn(request, _opts) ->
        send pid, request
        {:ok, %HTTPoison.Response{status_code: 200, headers: [], body: "body"}}
      end)
    on_exit fn -> :meck.unload end
    state = %{pid: pid, type: :static_state}
    state_getter = fn -> %{pid: pid, type: :generated_state} end
    {:ok, %{state: state, state_getter: state_getter}}
  end

  test "endpoint without path" do
    request = %Njord.Api.Request{method: :get, url: "http:///", body: "",
                                 headers: []}
    TestApi.ep_without_path
    assert_receive ^request
  end

  test "endpoint without arguments" do
    request = %Njord.Api.Request{method: :get,
                                 url: "http://njord-rocks.com/get",
                                 body: "",
                                 headers: []}
    TestApi.ep_without_args
    assert_receive ^request
  end

  test "endpoint with a single path argument" do
    request = %Njord.Api.Request{method: :get,
                                 url: "http://njord-rocks.com/get/1",
                                 body: "",
                                 headers: []}
    TestApi.ep_with_path_arg(1)
    assert_receive ^request
  end

  test "endpoint with path arguments" do
    request = %Njord.Api.Request{method: :get,
                                 url: "http://njord-rocks.com/get/1/foo",
                                 body: "",
                                 headers: []}
    TestApi.ep_with_path_args(1, "foo")
    assert_receive ^request
  end

  test "endpoint with path arguments and parameters" do
    request = %Njord.Api.Request{method: :get,
                                 url: "http://njord-rocks.com/get/1/foo?arg2=3&arg3=bar",
                                 body: "",
                                 headers: []}
    TestApi.ep_with_path_args_and_params(1, "foo", 3, "bar")
    assert_receive ^request
  end

  test "endpoint with body" do
    request = %Njord.Api.Request{method: :post,
                                 url: "http://njord-rocks.com/post/foo",
                                 body: "body",
                                 headers: []}
    TestApi.ep_with_body("foo", "body")
    assert_receive ^request
  end

  test "endpoint with params" do
    request = %Njord.Api.Request{method: :get,
                                 url: "http://njord-rocks.com/get/1?arg2=grok&arg1=bar",
                                 body: "",
                                 headers: []}
    TestApi.ep_with_params(1, "bar", params: [arg1: "foo", arg2: "grok"])
    assert_receive ^request
  end

  test "endpoint with headers" do
    request = %Njord.Api.Request{method: :get,
                                 url: "http:///",
                                 body: "",
                                 headers: [{"Header", "Value"}]}
    TestApi.ep_without_path(headers: [{"Header", "Value"}])
    assert_receive ^request
  end

  test "endpoint with state", %{state: state} do
    request = %Njord.Api.Request{method: :get,
                                 url: "http:///",
                                 body: "",
                                 headers: []}
    TestApi.ep_without_path(state: state)
    assert_receive :static_state
    assert_receive ^request
  end

  test "endpoint with generated state", %{state_getter: state_getter} do
    request = %Njord.Api.Request{method: :get,
                                 url: "http:///",
                                 body: "",
                                 headers: []}
    TestApi.ep_without_path(state_getter: state_getter)
    assert_receive :generated_state
    assert_receive ^request
  end

  test "endpoint with default generated state" do
    request = %Njord.Api.Request{method: :get,
                                 url: "http:///",
                                 body: "",
                                 headers: []}
    TestApi.ep_with_state
    assert_receive :default_state
    assert_receive ^request
  end

  test "GET endpoint" do
    TestApi.get
    assert_receive %Njord.Api.Request{method: :get}
  end

  test "POST endpoint" do
    TestApi.post
    assert_receive %Njord.Api.Request{method: :post}
  end

  test "PUT endpoint" do
    TestApi.put
    assert_receive %Njord.Api.Request{method: :put}
  end

  test "HEAD endpoint" do
    TestApi.head
    assert_receive %Njord.Api.Request{method: :head}
  end

  test "PATCH endpoint" do
    TestApi.patch
    assert_receive %Njord.Api.Request{method: :patch}
  end

  test "DELETE endpoint" do
    TestApi.delete
    assert_receive %Njord.Api.Request{method: :delete}
  end

  test "OPTIONS endpoint" do
    TestApi.options
    assert_receive %Njord.Api.Request{method: :options}
  end
end
