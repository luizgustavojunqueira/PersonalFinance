defmodule PersonalFinanceWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: PersonalFinanceWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"

  attr :auto_close, :integer,
    default: 5000,
    doc: "the time in milliseconds to automatically close the flash message"

  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind})}
      role="alert"
      class="toast toast-bottom toast-end z-50"
      {@rest}
      phx-hook="FlashAutoClose"
      data-auto-close={@auto_close}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap flex flex-row gap-2 items-center p-2 ml-4 rounded-lg",
        @kind == :info && "alert alert-info ",
        @kind == :error && "alert alert-error "
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle-mini" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle-mini" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark-solid" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>

        <div
          :if={@auto_close}
          class="absolute bottom-0 h-1 w-80 sm:w-96 max-w-80 sm:max-w-96 bg-base-300/50"
        >
          <div
            class={[
              "h-full origin-left",
              @kind == :info && "bg-info",
              @kind == :error && "bg-error",
              @auto_close && "animate-progress"
            ]}
            style={"animation-duration: #{@auto_close}ms;"}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch)
  attr :variant, :string, values: ~w(primary custom)
  attr :size, :string, values: ~w(xs sm md lg)
  attr :class, :any, default: nil

  attr :disabled, :boolean,
    default: false,
    doc: "the disabled flag for the button"

  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", "custom" => "", nil => "btn-primary btn-soft"}
    sizes = %{"xs" => "btn-xs", "sm" => "btn-sm", "md" => "btn-md", "lg" => "btn-lg"}

    internal_class = Map.fetch!(variants, assigns[:variant])
    size_class = if assigns[:size], do: Map.fetch!(sizes, assigns[:size]), else: nil

    custom_class = assigns[:class]

    combined_class =
      [internal_class, size_class, custom_class]
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(fn c -> if is_list(c), do: c, else: String.split(c, " ") end)
      |> Enum.uniq()
      |> Enum.join(" ")

    assigns = assign(assigns, combined_class: combined_class)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={["btn", @combined_class]} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button
        disabled={@disabled}
        class={[
          "btn",
          @combined_class
        ]}
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               range search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :option_icons, :map,
    default: %{},
    doc:
      "optional map of option values to icon specs (icon name string or rendered component)"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :disabled, :boolean, default: false, doc: "the disabled flag for inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="fieldset-legend">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class="checkbox checkbox-sm"
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = assign_new(assigns, :option_icons, fn -> %{} end)

    if map_size(assigns.option_icons) == 0 do
      select_without_icons(assigns)
    else
      select_with_icons(assigns)
    end
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2">
      <label>
        <span :if={@label} class="fieldset-legend">
          {@label}
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            "textarea",
            @errors != [] && "textarea-error"
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors} class="label">>{msg}</.error>
    </fieldset>
    """
  end

  def input(%{type: "color"} = assigns) do
    ~H"""
    <fieldset class="fieldset mb-2 w-full">
      <label class="flex flow row items-center gap-2">
        <span :if={@label} class="text-dark-green dark:text-offwhite fieldset-label mb-1">
          {@label}
        </span>
        <div class="relative w-12 h-12">
          <input
            type="color"
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            class="absolute inset-0 w-12 h-12 opacity-0 cursor-pointer"
            phx-hook="ColorPicker"
            data-color-display-id={"color-display-#{@id}"}
            {@rest}
          />
          <div
            id={"color-display-#{@id}"}
            class={[
              "w-12 h-12 rounded-full border-2 border-gray-300 shadow-md",
              @errors != [] && "ring-2 ring-red-500"
            ]}
            style={"background-color: #{Phoenix.HTML.Form.normalize_value(@type, @value)}"}
          >
          </div>
        </div>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </fieldset>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <fieldset class="fieldset w-full">
      <label>
        <legend :if={@label} class="fieldset-legend">
          {@label}
        </legend>
        <input
          type={@type}
          name={@name}
          disabled={@disabled}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            "input w-full focus:outline- :",
            @errors != [] && "input-error"
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors} class="label">{msg}</.error>
    </fieldset>
    """
  end

  defp select_without_icons(assigns) do
    ~H"""
    <fieldset class="fieldset w-full">
      <legend :if={@label} class="fieldset-legend">{@label}</legend>
      <div class="flex flex-col gap-1">
        <select
          id={@id}
          name={@name}
          class={[
            "select select-bordered w-full",
            @errors != [] && "select-error"
          ]}
          disabled={@disabled}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
        <span :if={@rest[:"data-hint"]} class="label-text-alt text-sm text-base-content/70">
          {@rest[:"data-hint"]}
        </span>
      </div>
      <.error :for={msg <- @errors} class="label text-error">{msg}</.error>
    </fieldset>
    """
  end

  defp select_with_icons(%{multiple: true} = _assigns) do
    raise ArgumentError, "option_icons are not supported for multiple select inputs"
  end

  defp select_with_icons(assigns) do
    icon_options =
      assigns.options
      |> normalize_select_options()
      |> Enum.map(&build_icon_option(&1, assigns.option_icons))
      |> maybe_prepend_prompt(assigns.prompt, assigns.option_icons)
      |> Enum.with_index()
      |> Enum.map(fn {option, idx} ->
        Map.put(option, :id, build_option_id(assigns, idx))
      end)

    assigns =
      assigns
      |> assign(:icon_options, icon_options)
      |> assign(:current_value, normalize_select_value(assigns.value))

    ~H"""
    <fieldset class="fieldset w-full">
      <legend :if={@label} class="fieldset-legend">{@label}</legend>
      <div class="flex flex-col gap-2">
        <div class="flex flex-row gap-2">
          <label
            :for={option <- @icon_options}
            class="cursor-pointer"
          >
            <input
              type="radio"
              id={option.id}
              name={@name}
              value={option.value}
              checked={option.value == @current_value}
              class="peer sr-only"
              disabled={@disabled}
              {@rest}
            />
            <div class="inline-flex items-center gap-2 rounded-2xl border border-base-300 bg-base-100 px-4 py-2 text-sm font-medium text-base-content transition focus-within:ring-2 focus-within:ring-primary/40 peer-checked:border-primary peer-checked:bg-primary/10 peer-checked:text-primary">
              <span :if={option.icon} class="flex items-center justify-center text-base-content/70">
                <.icon :if={icon_string?(option.icon)} name={option.icon} class="size-4" />
                <%= if icon_fun?(option.icon), do: option.icon.() %>
                <%= if icon_renderable?(option.icon), do: option.icon %>
              </span>
              <span class="whitespace-nowrap">{option.label}</span>
            </div>
          </label>
        </div>
        <span :if={@rest[:"data-hint"]} class="label-text-alt text-sm text-base-content/70">
          {@rest[:"data-hint"]}
        </span>
      </div>
      <.error :for={msg <- @errors} class="label text-error">{msg}</.error>
    </fieldset>
    """
  end

  defp normalize_select_options(nil), do: []

  defp normalize_select_options(options) do
    Enum.map(options, fn
      {label, value} -> {label, value}
      value -> {value, value}
    end)
  end

  defp build_icon_option({label, value}, icon_map) do
    normalized_value = to_option_value(value)

    %{
      label: label,
      value: normalized_value,
      icon: fetch_option_icon(icon_map, value, normalized_value)
    }
  end

  defp maybe_prepend_prompt(options, nil, _icon_map), do: options

  defp maybe_prepend_prompt(options, prompt, icon_map) do
    prompt_icon =
      fetch_option_icon(icon_map, :prompt, "") ||
        fetch_option_icon(icon_map, prompt, to_option_value(prompt))

    [%{label: prompt, value: "", icon: prompt_icon} | options]
  end

  defp build_option_id(assigns, idx) do
    base = assigns.id || assigns.name || "select"
    sanitized_base =
      base
      |> to_string()
      |> String.replace(~r/\s+/, "-")

    "#{sanitized_base}-option-#{idx}"
  end

  defp normalize_select_value(value) do
    value
    |> to_option_value()
  end

  defp to_option_value(nil), do: ""
  defp to_option_value(value) when is_binary(value), do: value
  defp to_option_value(value) when is_atom(value), do: Atom.to_string(value)
  defp to_option_value(value) when is_integer(value), do: Integer.to_string(value)
  defp to_option_value(value) when is_float(value), do: :erlang.float_to_binary(value, [:compact])
  defp to_option_value(value), do: to_string(value)

  defp fetch_option_icon(icon_map, raw_value, normalized_value) do
    icon_map[raw_value] ||
      icon_map[normalized_value] ||
      case safe_to_existing_atom(normalized_value) do
        nil -> nil
        atom_key -> icon_map[atom_key]
      end
  end

  defp safe_to_existing_atom(value) when is_binary(value) and value != "" do
    try do
      String.to_existing_atom(value)
    rescue
      ArgumentError -> nil
    end
  end

  defp safe_to_existing_atom(_), do: nil

  defp icon_string?(icon) when is_binary(icon), do: true
  defp icon_string?(_), do: false

  defp icon_fun?(icon) when is_function(icon, 0), do: true
  defp icon_fun?(_), do: false

  defp icon_renderable?(icon) do
    icon not in [nil, ""] and not icon_string?(icon) and not icon_fun?(icon)
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle-mini" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  attr :class, :string, default: nil

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      @actions != [] && "gap-6",
      "min-h-20 flex flex-col md:flex-row justify-between items-center m-2 mb-0",
      @class
    ]}>
      <div>
        <h1 class="text-3xl font-bold leading-8 text-dark-green dark:text-offwhite">
          {render_slot(@inner_block)}
        </h1>
        <p
          :if={@subtitle != []}
          class="text-sm text-base-content/70 text-dark-green/70 dark:text-offwhite/70"
        >
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Render a form modal with a title, subtitle, inputs, and actions.
  """
  attr :title, :string, required: true, doc: "the title of the modal"
  attr :subtitle, :string, default: nil, doc: "the subtitle of the modal"

  attr :id, :string,
    default: "form-modal",
    doc: "the id of the modal, used for targeting the modal dialog"

  attr :action, :atom,
    default: :new,
    values: [:new, :edit],
    doc: "the action to perform, used to determine the form title"

  attr :form, Phoenix.HTML.Form,
    required: true,
    doc: "the form to render, typically created with `to_form/1`"

  attr :submit_event, :string,
    default: "save",
    doc: "the event to trigger when the form is submitted"

  attr :submit_label, :string,
    default: "Salvar",
    doc: "the label for the submit button"

  attr :validate_event, :string,
    default: "validate",
    doc: "the event to trigger when the form is validated"

  attr :close_event, :string,
    default: "close_form",
    doc: "the event to trigger when the form is closed"

  attr :parent_pid, :any,
    default: nil,
    doc: "the parent process pid to target for events"

  attr :rest, :global,
    include: ~w(id class phx-target phx-hook phx-click phx-submit phx-change),
    doc: "the arbitrary HTML attributes to add to the form"

  slot :inner_block, doc: "The content to render inside the form, typically inputs."

  def form_modal(assigns) do
    ~H"""
    <div
      class="fixed z-50 top-0 left-0 w-full h-full flex items-center justify-center bg-black/60 "
      {@rest}
    >
      <div
        class="bg-base-200 rounded-xl shadow-2xl p-6 w-full max-w-2xl"
        phx-mounted={
          JS.transition(
            {"transition-all ease-out duration-200",
             "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
             "opacity-100 translate-y-0 sm:scale-100"},
            time: 200
          )
        }
      >
        <div class="flex flex-row justify-between mb-5 items-center">
          <div class="flex flex-col ">
            <h2 class="text-2xl font-semibold  ">
              {if @action == :edit, do: "Editar " <> @title, else: "Cadastrar " <> @title}
            </h2>
            <span
              :if={@subtitle}
              class="mt-1 text-sm text-base-content/70 text-text-lightmode-light/70 dark:text-text-darkmode-light/70"
            >
              {@subtitle}
            </span>
          </div>
          <.link class="text-red-600 hover:text-red-800 hero-x-mark" phx-click={@close_event}></.link>
        </div>

        <.form
          for={@form}
          phx-submit={@submit_event}
          phx-change={@validate_event}
          phx-target={@parent_pid}
          class="flex flex-col gap-4"
        >
          {render_slot(@inner_block, @form)}

          <.button variant="primary" phx-disable-with="Salvando">
            <.icon name="hero-check" /> {@submit_label}
          </.button>
        </.form>
      </div>
    </div>
    """
  end

  @doc ~S"""
  Renders a table with generic styling.
  ## Examples
      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
        <:col :let={user} label="status">
          <span class="badge">{user.status}</span>
        </:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  attr :col_widths, :list, default: [], doc: "the widths of each column, in pixels or percentage"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    assigns = assign(assigns, col_widths: assigns[:col_widths] || [])

    ~H"""
    <div class="relative w-full overflow-x-auto bg-base-100/80 border border-base-300 rounded-2xl shadow-sm transition-colors duration-300">
      <table class="w-full text-sm transition-colors duration-300">
        <thead class="bg-base-200/70 text-base-content/70">
          <tr class="text-left">
            <th
              :for={{col, idx} <- Enum.with_index(@col)}
              class="p-3 font-semibold transition-colors duration-300"
              style={
                if Enum.at(@col_widths, idx), do: "width: #{Enum.at(@col_widths, idx)}", else: ""
              }
            >
              <div class="truncate" title={col[:label]}>{col[:label]}</div>
            </th>
            <th :if={@action != []} class="p-3 w-px">
              <div class="text-right whitespace-nowrap">{gettext("Actions")}</div>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            phx-click={@row_click && @row_click.(row)}
            class={
              "transition-colors duration-300 border-b border-base-300/60 last:border-none bg-base-100 even:bg-base-200/40 " <>
                if(@row_click, do: "hover:bg-base-200/80 hover:cursor-pointer", else: "")
            }
          >
            <td
              :for={{col, idx} <- Enum.with_index(@col)}
              class="p-4 transition-colors duration-300 align-middle"
              style={
                if Enum.at(@col_widths, idx), do: "width: #{Enum.at(@col_widths, idx)}", else: ""
              }
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="p-4 w-px align-middle">
              <div class="flex justify-end gap-3 whitespace-nowrap text-base-content/80">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div>
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders a confirmation modal.
  """
  attr :title, :string, required: true, doc: "the title of the confirmation modal"
  attr :message, :string, required: true, doc: "the message to display in the confirmation modal"

  attr :confirm_event, :string,
    default: "confirm",
    doc: "the event to trigger when the user confirms the action"

  attr :cancel_event, :string,
    default: "",
    doc: "the event to trigger when the user cancels the action"

  attr :item_id, :any, default: nil, doc: "the id of the item to confirm the action for"

  attr :rest, :global,
    include: ~w(id class phx-target phx-hook phx-click),
    doc: "the arbitrary HTML attributes to add to the confirmation modal"

  def confirmation_modal(assigns) do
    ~H"""
    <div
      class="fixed z-50 top-0 left-0 w-full h-full flex items-center justify-center bg-black/60"
      {@rest}
    >
      <div
        class="bg-base-100 rounded-xl shadow-2xl p-6 w-full max-w-md"
        phx-mounted={
          JS.transition(
            {"transition-all ease-out duration-200",
             "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
             "opacity-100 translate-y-0 sm:scale-100"},
            time: 200
          )
        }
      >
        <h2 class="text-2xl font-semibold mb-4">{@title}</h2>
        <p class="mb-6">{@message}</p>
        <div class="flex justify-end gap-4">
          <.button phx-click={@cancel_event} variant="custom" class="btn btn-soft">
            Cancelar
          </.button>
          <.button
            class="btn btn-primary"
            phx-click={@confirm_event}
            phx-value-id={@item_id}
            phx-disable-with="Confirmando"
          >
            Confirmar
          </.button>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_close, JS, default: nil
  attr :backdrop_close, :boolean, default: true
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(id phx-hook phx-click phx-submit phx-change)

  slot :title
  slot :content
  slot :inner_block
  slot :actions

  def modal(assigns) do
    assigns = assign(assigns, :class_list, class_to_list(assigns.class))

    ~H"""
    <div
      :if={@show}
      id={@id}
      class="fixed z-50 inset-0 flex items-center justify-center bg-black/60"
      phx-mounted={JS.transition({"ease-out duration-200", "opacity-0", "opacity-100"}, time: 200)}
      phx-remove={JS.transition({"ease-in duration-100", "opacity-100", "opacity-0"}, time: 100)}
      {@rest}
    >
      <div
        class="fixed inset-0"
        phx-click={if @backdrop_close, do: @on_close}
      />
      <div
        class={["bg-base-200 rounded-xl shadow-2xl p-6 w-full max-w-2xl", @class_list]}
        phx-mounted={
          JS.transition({"ease-out duration-200", "opacity-0 scale-95", "opacity-100 scale-100"},
            time: 200
          )
        }
      >
        <div class="flex justify-between items-center mb-5">
          <h2 :if={@title != []} class="text-2xl font-semibold">{render_slot(@title)}</h2>
          <.button
            phx-click={@on_close}
            variant="custom"
            class="text-red-600 hover:text-red-800 btn btn-ghost"
          >
            <.icon name="hero-x-mark" class="text-2xl" />
          </.button>
        </div>
        <div :if={@content != []} class="mb-4 space-y-2">
          {render_slot(@content)}
        </div>
        <div :if={@inner_block != []}>
          {render_slot(@inner_block)}
        </div>
        <div :if={@actions != []} class="flex justify-end gap-2 mt-4">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_close, JS, default: nil
  attr :backdrop_close, :boolean, default: true
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(id phx-hook phx-click phx-submit phx-change)

  slot :title
  slot :inner_block, required: true
  slot :actions

  def side_modal(assigns) do
    assigns = assign(assigns, :class_list, class_to_list(assigns.class))

    ~H"""
    <div
      :if={@show}
      id={@id}
      class="fixed inset-0 z-50 flex justify-end bg-black/60 mb-0"
      phx-mounted={JS.transition({"ease-out duration-200", "opacity-0", "opacity-100"}, time: 200)}
      phx-remove={JS.transition({"ease-in duration-100", "opacity-100", "opacity-0"}, time: 100)}
      {@rest}
    >
      <div
        class="fixed inset-0"
        phx-click={if @backdrop_close, do: @on_close}
      />
      <div
        class={[
          "relative h-full w-full max-w-2xl bg-base-200 dark:bg-base-900 shadow-2xl p-6 overflow-y-auto",
          @class_list
        ]}
        phx-mounted={
          JS.transition({"ease-out duration-200", "translate-x-full", "translate-x-0"}, time: 200)
        }
      >
        <div class="flex justify-between items-center mb-5">
          <h2 :if={@title != []} class="text-2xl font-semibold">{render_slot(@title)}</h2>
          <.button
            phx-click={@on_close}
            variant="custom"
            class="text-red-600 hover:text-red-800 btn btn-ghost"
          >
            <.icon name="hero-x-mark" class="text-2xl" />
          </.button>
        </div>
        {render_slot(@inner_block)}
        <div :if={@actions != []} class="flex justify-end gap-2 mt-4">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  defp class_to_list(class) when is_binary(class), do: String.split(class, " ", trim: true)
  defp class_to_list(class) when is_list(class), do: class
  defp class_to_list(_), do: []

  @doc """
  Text label with ellipsis for long text.
  """
  attr :text, :string, required: true, doc: "the text to display in the label"
  attr :class, :string, default: "", doc: "the additional classes to apply to the label"

  attr :max_width, :string,
    default: "max-w-xs",
    doc: "the maximum width of the label, defaults to 'max-w-xs'"

  def text_ellipsis(assigns) do
    ~H"""
    <p
      class={[
        "truncate",
        @max_width,
        @class
      ]}
      title={@text}
    >
      {@text}
    </p>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(PersonalFinanceWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(PersonalFinanceWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
