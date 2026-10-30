defmodule FrontWeb.BookingColorsTest do
  use ExUnit.Case, async: true

  test "booking screens use navy headings and teal primary actions" do
    home =
      render(FrontWeb.HomeLive, %{
        destino: nil,
        data_embarque: nil,
        porto_embarque: nil,
        itinerarios: [
          %{
            "destino" => "Caribe",
            "navio" => "Mar Azul",
            "datas_disponiveis" => ["2026-11-01"],
            "porto_embarque" => "Santos",
            "porto_desembarque" => "Santos",
            "lugares_visitados" => ["Ilha"],
            "noites" => 7,
            "valor_por_pessoa" => 1000
          }
        ]
      })

    assert home =~ ~s(class="text-3xl font-bold text-slate-900 mb-4")
    assert home =~ "bg-brand hover:bg-teal-800 text-white"
    refute home =~ "bg-red-600"

    index =
      render(FrontWeb.ReservaLive.Index, %{
        reservas: [
          %{
            id: "1",
            cruzeiro_id: "c1",
            data_criacao: "2026-10-01",
            valor_total: 2000,
            status: "pagamento_aprovado"
          }
        ]
      })

    assert index =~ "text-slate-900"
    assert index =~ "bg-brand hover:bg-teal-800 text-white"
    assert index =~ "bg-blue-100 text-blue-800"

    new =
      render(FrontWeb.ReservaLive.New, %{
        page_title: "Nova Reserva",
        destino: "",
        data_embarque: "",
        porto_embarque: "",
        itinerarios: [],
        step: 1
      })

    assert new =~ "text-slate-900"
    assert new =~ "bg-brand hover:bg-teal-800 text-white"

    show =
      render(FrontWeb.ReservaLive.Show, %{
        reserva: %{
          "id" => "1",
          "status" => "pendente",
          "data_criacao" => "2026-10-01",
          "link_pagamento" => "https://pay.example/1",
          "num_passageiros" => 2,
          "num_cabines" => 1,
          "cruzeiro_id" => "c1",
          "valor_total" => 2000,
          "bilhete" => nil
        }
      })

    assert show =~ "text-slate-900"
    assert show =~ "text-brand"
    assert show =~ "bg-green-100 border border-green-500"

    assinante = render(FrontWeb.AssinanteLive, %{})
    assert assinante =~ ~s(class="text-slate-900")
  end

  defp render(live_view, assigns) do
    live_view.render(assigns)
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end
end
