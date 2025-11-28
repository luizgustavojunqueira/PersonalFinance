export const Chart = {

  mounted() {
    selector = "#" + this.el.id;
    this.chart = echarts.init(this.el.querySelector(selector + "-chart"));
    option = JSON.parse(
      this.el.querySelector(selector + "-data").textContent,
    );
    this._updateChartOptions();
    window.addEventListener("resize", () => {
      this.chart.resize();
    });
  },

  updated() {
    this._updateChartOptions();
  },

  _updateChartOptions() {
    selector = "#" + this.el.id;
    option = JSON.parse(
      this.el.querySelector(selector + "-data").textContent,
    );

    const restanteSeries = option.series.find((s) => s.name === "Restante");
    if (restanteSeries && restanteSeries.label) {
      restanteSeries.label.formatter = function (params) {
        return params.name === "Sem Categoria"
          ? ""
          : "R$" + params.value;
      };
    }

    const metaSeries = option.series.find((s) => s.name === "Meta");
    if (metaSeries && metaSeries.label) {
      metaSeries.label.formatter = function (params) {
        return params.name === "Sem Categoria"
          ? ""
          : "R$" + params.value;
      };
    }

    this.chart.setOption(option);
  },
}
