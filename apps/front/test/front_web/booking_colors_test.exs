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

    assert html =~ "text-slate-900"
    assert html =~ "Bem-vindo ao CruzeiroMar"
    assert html =~ "bg-brand"
    assert html =~ "Minhas Reservas"

    refute html =~ "bg-red-600"
    refute html =~ "hover:bg-red-700"
  end

  test "reservation list keeps status badges and recolors actions" do
    badges = %{
      "pendente" => "bg-yellow-100 text-yellow-800",
      "pagamento_aprovado" => "bg-blue-100 text-blue-800",
      "bilhete_gerado" => "bg-green-100 text-green-800",
      "cancelada" => "bg-red-100 text-red-800"
    }

    for {status, badge} <- badges do
      html = render(FrontWeb.ReservaLive.Index, %{reservas: [reserva(status)]})

      assert html =~ "text-slate-900"
      assert html =~ "Minhas Reservas"
      assert html =~ "bg-brand"
      assert html =~ "Nova Reserva"
      assert html =~ "text-brand"
      assert html =~ "Detalhes"
      assert html =~ badge
    end
  end

  test "new reservation step 1 uses teal actions and navy headings" do
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
  end

  test "new reservation step 4 keeps the success panel and recolors the payment link" do
    html =
      render(FrontWeb.ReservaLive.New, %{
        page_title: "Nova Reserva",
        step: 4,
        reserva: %{
          "link_pagamento" => "https://pay.example/1",
          "id" => "r1",
          "status" => "pendente",
          "data_criacao" => "2026-01-01"
        }
      })

    assert html =~ "text-brand"
    assert html =~ "Clique aqui para pagar"
    assert html =~ "bg-green-100"
  end

  test "reservation detail keeps the success panel and recolors the payment link" do
    html =
      render(FrontWeb.ReservaLive.Show, %{
        reserva: %{
          "id" => "r1",
          "status" => "pendente",
          "data_criacao" => "2026-01-01",
          "link_pagamento" => "https://pay.example/1",
          "num_passageiros" => 2,
          "num_cabines" => 1,
          "cruzeiro_id" => "c1",
          "valor_total" => 100,
          "bilhete" => %{"codigo" => "ABC"}
        }
      })

    assert html =~ "text-slate-900"
    assert html =~ "Detalhes da Reserva"
    assert html =~ "text-brand"
    assert html =~ "Clique aqui para pagar"
    assert html =~ "bg-green-100"
  end

  test "subscriber heading is deep navy" do
    html = render(FrontWeb.AssinanteLive, %{})

    assert html =~ "text-slate-900"
    assert html =~ "Área do Assinante"
  end

  test "brand token, page background, and header chip" do
    tailwind = File.read!(Path.join(@front_root, "assets/tailwind.config.js"))
    root = File.read!(Path.join(@front_root, "lib/front_web/components/layouts/root.html.heex"))
    app = File.read!(Path.join(@front_root, "lib/front_web/components/layouts/app.html.heex"))

    assert tailwind =~ "#0F766E"
    refute tailwind =~ "#FD4F00"
    assert root =~ "bg-slate-50"
    assert app =~ "text-brand"
    assert app =~ "bg-brand/5"
  end

  defp render(module, assigns) do
    module.render(Map.put_new(assigns, :socket, %Phoenix.LiveView.Socket{}))
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp reserva(status) do
    %{
      id: "r1",
      status: status,
      cruzeiro_id: "c1",
      data_criacao: "2026-01-01",
      valor_total: 100
    }
  end
end
