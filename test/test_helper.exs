defmodule NjordTestHTTP do
  alias HTTPoison.Response

  def request(method, url, body, headers, options) do
    body = %{method: method,
              url: url,
              body: body,
              headers: headers,
              options: options}
    %Response{status_code: 200,
              body: body,
              headers: []}
  end
end

ExUnit.start()
