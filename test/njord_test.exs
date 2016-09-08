defmodule NjordTest do
  use ExUnit.Case, async: true

  defmodule NjordTestApi do
    use Njord

    defendpoint :endpoint0, :get, [path: "/endpoint/0"]

    defendpoint :endpoint1, :get,
      [path: "/endpoint/:number",
       arguments: [number: [type: :path_arg, validation: fn x -> x == 1 end]]]

    defendpoint :endpoint2, :get,
      [path: "/endpoint/2",
       arguments: [number: [type: :arg, validation: fn x -> x == 2 end]]]

    defendpoint :endpoint3, :post,
      [path: "/endpoint/3",
       arguments: [number: [type: :body, validation: fn x -> x == 3 end]]]

    defendpoint :endpoint4, :get,
      [path: "/endpoint/4",
       arguments: [a: [type: :arg, validation: fn x -> x == 4 end]]]

    defendpoint :endpoint5, :post,
      [path: "/endpoint/5",
       arguments: [a: [type: :body]]]

    defendpoint :endpoint6, :get, [path: "/endpoint/6"]

    defget :get_endpoint, [path: "/get"]

    defpost :post_endpoint, [path: "/post"]
    
    defput :put_endpoint, [path: "/put"]

    defdelete :delete_endpoint, [path: "/delete"]
    
    defhead :head_endpoint, [path: "/head"]
    
    defpatch :patch_endpoint, [path: "/patch"]
    
    defoptions :options_endpoint, [path: "/options"]
  end

  test "join_query/2 no query" do
    url = "example.com/"
    request = %Njord{params: []}
    expected = %Njord{request | url: "http://" <> url}
    assert expected == Njord.join_query(request, url)

    url = "http://example.com/"
    assert expected == Njord.join_query(request, url)

    url = "https://example.com/"
    expected = %Njord{request | url: url}
    assert expected == Njord.join_query(request, url)
  end

  test "join_query/2 with query" do
    url = "example.com/"
    request = %Njord{params: [a: 4, b: 2]}
    expected = %Njord{params: [a: 4, b: 2], url: "http://example.com/?a=4&b=2"}
    assert expected == Njord.join_query(request, url)
  end

  test "Empty get endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :get,
        options: [],
        url: "http:///endpoint/0"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.endpoint0()
  end

  test "Path arg endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :get,
        options: [],
        url: "http:///endpoint/1"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.endpoint1(1)
  end

  test "Arg endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :get,
        options: [],
        url: "http:///endpoint/2?number=2"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.endpoint2(2)
  end

  test "Body endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [number: 3],
        headers: [],
        method: :post,
        options: [],
        url: "http:///endpoint/3"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.endpoint3(3)
  end

  test "Merge params endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :get,
        options: [],
        url: "http:///endpoint/4?b=2&a=4"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.endpoint4(4, [params: [b: 2]])
  end

  test "Merge body endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [b: 2, a: 4],
        headers: [],
        method: :post,
        options: [],
        url: "http:///endpoint/5"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.endpoint5(4, [body: [b: 2]])
  end

  test "Headers endpoint" do
    headers = [{"Header", "Value"}]
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: headers,
        method: :get,
        options: [],
        url: "http:///endpoint/6"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.endpoint6([headers: headers])
  end

  test "Njord default process_url/3" do
    url = "example.com/"
    expected = %Njord{params: [a: 42], url: "http://" <> url <> "?a=42"}
    assert expected == NjordTestApi.process_url(expected, url, nil)
  end

  test "Njord default process_body/3" do
    body = [a: 42]
    expected = %Njord{body: body}
    assert expected == NjordTestApi.process_body(expected, body, nil)
  end

  test "Njord default process_headers/3" do
    headers = [{"Header", "Value"}]
    expected = %Njord{headers: headers}
    assert expected == NjordTestApi.process_headers(expected, headers, nil)
  end

  test "Njord default process_status_code/4" do
    status_code = 200
    expected = %HTTPoison.Response{status_code: status_code}
    result = NjordTestApi.process_status_code(expected, :any, status_code, nil) 
    assert expected == result
  end

  test "Njord default process_response_headers/4" do
    headers = [{"Header", "Value"}]
    expected = %HTTPoison.Response{headers: headers}
    result = NjordTestApi.process_response_headers(expected, :any, headers, nil) 
    assert expected == result
  end

  test "Njord default process_response_body/4" do
    body = [a: 42]
    expected = %HTTPoison.Response{body: body}
    result = NjordTestApi.process_response_body(expected, :any, body, nil) 
    assert expected == result
  end

  test "defget endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :get,
        options: [],
        url: "http:///get"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.get_endpoint()
  end

  test "defpost endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :post,
        options: [],
        url: "http:///post"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.post_endpoint()
  end

  test "defput endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :put,
        options: [],
        url: "http:///put"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.put_endpoint()
  end

  test "defdelete endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :delete,
        options: [],
        url: "http:///delete"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.delete_endpoint()
  end

  test "defhead endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :head,
        options: [],
        url: "http:///head"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.head_endpoint()
  end

  test "defpatch endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :patch,
        options: [],
        url: "http:///patch"
      },
      headers: [],
      status_code: 200
    }
    assert {:ok, expected} == NjordTestApi.patch_endpoint()
  end

  test "defoptions endpoint" do
    expected = %HTTPoison.Response{
      body: %{
        body: [],
        headers: [],
        method: :options,
        options: [],
        url: "http:///options"
      },
      headers: [],
      status_code: 200
    }

    assert {:ok, expected} == NjordTestApi.options_endpoint()
  end
end
