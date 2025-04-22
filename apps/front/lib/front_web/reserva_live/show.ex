defmodule FrontWeb.ReservaLive.Show do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Detalhes da Reserva</h1>
    <p>Exibindo informações da reserva...</p>
    """
  end
end
