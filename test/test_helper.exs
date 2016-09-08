defmodule NjordTestHTTP do
  alias HTTPoison.Response

  def request(method, url, body, headers, options) do
    body = %{method: method,
              url: url,
              body: body,
              headers: headers,
              options: options}
    response =  %Response{status_code: 200, body: body, headers: []}
    {:ok, response}
  end
end

ExUnit.start()
