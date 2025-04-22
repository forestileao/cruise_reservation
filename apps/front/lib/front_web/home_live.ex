defmodule FrontWeb.HomeLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Home")}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="bg-white rounded-lg shadow-md p-6 mb-6">
        <h1 class="text-3xl font-bold text-blue-700 mb-4">Bem-vindo ao CruzeiroMar</h1>
        <p class="text-gray-700 mb-4">
          Descubra o mundo navegando em nossos luxuosos cruzeiros. Oferecemos destinos incríveis,
          acomodações confortáveis e experiências inesquecíveis.
        </p>

        <div class="mt-6 flex space-x-4">
        <a href="/reservas" class="bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded">
            Minhas Reservas
          </a>
          <a href="/reservas/nova" class="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
            Fazer uma Reserva
          </a>
          <a href="/assinante" class="bg-green-600 hover:bg-green-700 text-white font-bold py-2 px-4 rounded">
            Assinar Promoções
          </a>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow-md p-6">
        <h2 class="text-2xl font-bold text-blue-700 mb-4">Nossos Destinos Populares</h2>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="bg-gray-100 p-4 rounded-lg">
            <h3 class="font-bold text-lg mb-2">Caribe</h3>
            <p class="text-gray-700">Águas cristalinas, praias de areia branca e cultura vibrante.</p>
          </div>

          <div class="bg-gray-100 p-4 rounded-lg">
            <h3 class="font-bold text-lg mb-2">Mediterrâneo</h3>
            <p class="text-gray-700">História milenar, gastronomia incrível e paisagens deslumbrantes.</p>
          </div>

          <div class="bg-gray-100 p-4 rounded-lg">
            <h3 class="font-bold text-lg mb-2">Alasca</h3>
            <p class="text-gray-700">Geleiras majestosas, vida selvagem fascinante e natureza intocada.</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
