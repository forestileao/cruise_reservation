defmodule MsReserva.BlacklistAgent do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  def add_ip(ip) do
    Agent.update(__MODULE__, fn blacklist ->
      MapSet.put(blacklist, ip)
    end)
    IO.puts("IP #{ip} adicionado à blacklist")
  end

  def remove_ip(ip) do
    Agent.update(__MODULE__, fn blacklist ->
      MapSet.delete(blacklist, ip)
    end)
    IO.puts("IP #{ip} removido da blacklist")
  end

  def is_blacklisted?(ip) do
    Agent.get(__MODULE__, fn blacklist ->
      MapSet.member?(blacklist, ip)
    end)
  end

  def list_blacklisted_ips do
    Agent.get(__MODULE__, fn blacklist ->
      MapSet.to_list(blacklist)
    end)
  end
end
