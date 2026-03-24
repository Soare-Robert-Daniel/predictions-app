defmodule PredictionsWeb.PageController do
  use PredictionsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
