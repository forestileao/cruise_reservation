defmodule FrontWeb.ErrorJSONTest do
  use FrontWeb.ConnCase, async: true

  test "renders 404" do
    assert FrontWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert FrontWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
