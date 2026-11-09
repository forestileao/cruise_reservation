defmodule FrontWeb.BookingColorsTest do
  use ExUnit.Case, async: true

  @front_root Path.expand("../..", __DIR__)

  test "home uses navy headings and teal primary actions" do
    html =
      render(FrontWeb.HomeLive, %{
        destino: nil,
        data_embarque: nil,
        porto_embarque: nil,
        itinerarios: []
      })

    assert html =~
             ~s(<h1 class="text-3xl font-bold text-slate-900 mb-4">Bem-vindo ao CruzeiroMar</h1>)

    assert html =~
             ~r/class="bg-brand hover:bg-teal-800 text-white font-bold py-2 px-4 rounded"\s*>\s*Minhas Reservas/

    refute html =~ "bg-red-600"
    refute html =~ "hover:bg-red-700"
  end

  test "reservation list uses navy heading, teal action, and keeps status badges" do
    for {status, badge} <- [
          {"pendente", "bg-yellow-100 text-yellow-800"},
          {"pagamento_aprovado", "bg-blue-100 text-blue-800"},
          {"bilhete_gerado", "bg-green-100 text-green-800"},
          {"cancelada", "bg-red-100 text-red-800"}
        ] do
      html = render(FrontWeb.ReservaLive.Index, %{reservas: [reserva(status)]})

      assert html =~ ~s(<h1 class="text-3xl font-bold text-slate-900">Minhas Reservas</h1>)

      assert html =~
               ~s(class="bg-brand hover:bg-teal-800 text-white font-bold py-2 px-4 rounded")

      assert html =~ "Nova Reserva"
      assert html =~ ~r/class="text-brand hover:text-teal-800"\s*>\s*Detalhes/
      assert html =~ badge
    end
  end

  test "new reservation step 1 uses teal action and navy heading" do
    html =
      render(FrontWeb.ReservaLive.New, %{
        page_title: "Nova Reserva",
        step: 1,
        destino: "",
        data_embarque: "",
        porto_embarque: ""
      })

    assert html =~ "bg-brand"
    assert html =~ "text-slate-900"
    assert html =~ "Buscar Itinerários"
  end

  test "new reservation step 4 keeps the green success panel and teal payment link" do
    html =
      render(FrontWeb.ReservaLive.New, %{
        page_title: "Nova Reserva",
        step: 4,
        reserva: %{
          "id" => "r1",
          "link_pagamento" => "https://pay.example/r1",
          "status" => "pendente",
          "data_criacao" => "2026-01-01"
        }
      })

    assert html =~ ~s(class="text-brand">Clique aqui para pagar</a>)
    assert html =~ "bg-green-100"
  end

  test "reservation detail keeps the green success panel and teal payment link" do
    html =
      render(FrontWeb.ReservaLive.Show, %{
        reserva: %{
          "id" => "r1",
          "status" => "pendente",
          "data_criacao" => "2026-01-01",
          "link_pagamento" => "https://pay.example/r1",
          "num_passageiros" => 2,
          "num_cabines" => 1,
          "cruzeiro_id" => "c1",
          "valor_total" => 1000,
          "bilhete" => %{"codigo" => "ABC123"}
        }
      })

    assert html =~ ~s(<h1 class="text-3xl font-bold text-slate-900 mb-4">Detalhes da Reserva</h1>)
    assert html =~ ~s(class="text-brand">Clique aqui para pagar</a>)
    assert html =~ "bg-green-100"
  end

  test "subscriber heading is navy" do
    html = render(FrontWeb.AssinanteLive, %{})

    assert html =~ ~s(<h1 class="text-slate-900">Área do Assinante</h1>)
  end

  test "brand token and shared layout colors" do
    tailwind = File.read!(Path.join(@front_root, "assets/tailwind.config.js"))
    assert tailwind =~ "#0F766E"
    refute tailwind =~ "#FD4F00"

    root = File.read!(Path.join(@front_root, "lib/front_web/components/layouts/root.html.heex"))
    assert root =~ "bg-slate-50"

    app = File.read!(Path.join(@front_root, "lib/front_web/components/layouts/app.html.heex"))
    assert app =~ "text-brand"
    assert app =~ "bg-brand/5"
  end

  defp render(view, assigns) do
    view.render(assigns)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp reserva(status) do
    %{
      id: "r1",
      status: status,
      cruzeiro_id: "c1",
      data_criacao: "2026-01-01",
      valor_total: 1000
    }
  end
end
