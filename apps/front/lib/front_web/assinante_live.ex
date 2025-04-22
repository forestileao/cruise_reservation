defmodule FrontWeb.AssinanteLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h1>Área do Assinante</h1>
    <p>Bem-vindo à área do assinante!</p>
    """
  end
end
