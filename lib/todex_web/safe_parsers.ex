defmodule TodexWeb.SafeParsers do
  alias TodexWeb.Errors

  @parser_opts Plug.Parsers.init(
                 parsers: [:json, :urlencoded, :multipart],
                 pass: ["*/*"],
                 json_decoder: Jason,
                 length: 1_000_000
               )

  def init(opts), do: opts

  def call(conn, _opts) do
    Plug.Parsers.call(conn, @parser_opts)
  rescue
    error in Plug.Parsers.ParseError ->
      Errors.handle_error(conn, error)

    error ->
      Errors.handle_error(conn, error)
  end
end
