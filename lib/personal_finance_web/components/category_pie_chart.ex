defmodule PersonalFinanceWeb.Components.CategoryPieChart do
  use Phoenix.Component

  alias PersonalFinance.Utils.ParseUtils, as: Parse

  @doc """
  Renders a category pie chart component.

  ## Examples

      <.category_pie_chart
        id="expense-chart"
        title="Expenses by category"
        categories={@expense_categories}
        empty_message="No expense data"
      />
  """
  attr :id, :string, required: true, doc: "Unique identifier for the chart"
  attr :title, :string, required: true, doc: "Chart title"
  attr :categories, :list, required: true, doc: "List of category maps with category_name, category_color, and total"
  attr :empty_message, :string, default: "No data available", doc: "Message to show when there's no data"
  attr :class, :string, default: "", doc: "Additional CSS classes"

  def category_pie_chart(assigns) do
    ~H"""
    <div class={["rounded-2xl border border-base-300 bg-base-100/80 p-6 shadow-sm", @class]}>
      <h3 class="text-lg font-semibold text-base-content mb-4">
        {@title}
      </h3>
      <%= if @categories == [] do %>
        <div class="text-center text-base-content/60 py-8">
          <p class="text-sm">{@empty_message}</p>
        </div>
      <% else %>
        <div class="rounded-xl bg-base-200/60 p-4">
          <div id={@id} phx-hook="Chart" class="h-80 w-full">
            <div id={"#{@id}-chart"} class="w-full h-80" phx-update="ignore" />
            <div id={"#{@id}-data"} hidden>
              {Jason.encode!(build_chart_option(@categories))}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp build_chart_option(categories) do
    data =
      Enum.map(categories, fn cat ->
        name = Map.get(cat, :category_name) || Map.get(cat, :name) || Map.get(cat, "category_name") || Map.get(cat, "name")
        color = Map.get(cat, :category_color) || Map.get(cat, :color) || Map.get(cat, "category_color") || Map.get(cat, "color")

        %{
          value: Parse.parse_float(cat.total),
          name: name,
          itemStyle: %{color: color}
        }
      end)

    %{
      tooltip: %{trigger: "item", formatter: "{b}: {c} ({d}%)"},
      legend: %{
        orient: "vertical",
        left: "left",
        data: Enum.map(data, & &1.name)
      },
      series: [
        %{
          type: "pie",
          radius: ["40%", "70%"],
          avoidLabelOverlap: false,
          itemStyle: %{
            borderRadius: 10,
            borderColor: "#fff",
            borderWidth: 2
          },
          label: %{
            show: true,
            formatter: "{b}: {d}%"
          },
          emphasis: %{
            label: %{
              show: true,
              fontSize: 16,
              fontWeight: "bold"
            }
          },
          data: data
        }
      ]
    }
  end

end
