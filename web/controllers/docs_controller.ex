defmodule HexWeb.DocsController do
  use HexWeb.Web, :controller

  def show_usage(conn, _params) do
    render conn, "usage.html", [
      active: :docs,
      title: "Mix Usage"
    ]
  end

  def show_rebar3_usage(conn, _params) do
    render conn, "rebar3_usage.html", [
      active: :docs,
      title: "Rebar3 Usage"
    ]
  end

  def show_publish(conn, _params) do
    render conn, "publish.html", [
      active: :docs,
      title: "Mix publish package"
    ]
  end

  def show_rebar3_publish(conn, _params) do
    render conn, "rebar3_publish.html", [
      active: :docs,
      title: "Rebar3 publish package"
    ]
  end

  def show_tasks(conn, _params) do
    render conn, "tasks.html", [
      active: :docs,
      title: "Mix tasks"
    ]
  end

  def show_coc(conn, _params) do
    render conn, "coc.html", [
      active: :docs,
      title: "Code of Conduct"
    ]
  end

  def show_faq(conn, _params) do
    render conn, "faq.html", [
      active: :docs,
      title: "FAQ"
    ]
  end

  def show_mirrors(conn, _params) do
    render conn, "mirrors.html", [
      active: :docs,
      title: "Mirrors"
    ]
  end
end
