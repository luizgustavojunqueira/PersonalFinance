defmodule PersonalFinanceWeb.LocaleHook do
  @moduledoc """
  Sets the locale based on the params passed from the client.
  """
  import Phoenix.LiveView, only: [get_connect_params: 1]

  def on_mount(:default, _params, _session, socket) do
    locale = get_connect_params(socket)["locale"] || "en"
    Gettext.put_locale(PersonalFinanceWeb.Gettext, locale)
    {:cont, socket}
  end
end
