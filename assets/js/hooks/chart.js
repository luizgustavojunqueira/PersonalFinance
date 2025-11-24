import * as echarts from "../../vendor/echarts.min.js";

const cloneOption = (obj) => {
  if (!obj) return obj;
  return JSON.parse(JSON.stringify(obj));
};

const readThemePalette = () => {
  const defaults = {
    text: "#111827",
    surface: "#ffffff",
    border: "#d1d5db",
  };

  if (!document.body) {
    return defaults;
  }

  const probe = document.createElement("div");
  probe.style.position = "absolute";
  probe.style.visibility = "hidden";
  probe.style.pointerEvents = "none";
  probe.style.width = "0";
  probe.style.height = "0";
  probe.className = "bg-base-100 text-base-content border border-base-300";
  document.body.appendChild(probe);

  const styles = getComputedStyle(probe);
  const palette = {
    text: styles.color || defaults.text,
    surface: styles.backgroundColor || defaults.surface,
    border: styles.borderTopColor || defaults.border,
  };

  document.body.removeChild(probe);
  return palette;
};

const withAlpha = (color, alpha) => {
  if (!color) {
    return color;
  }

  if (color.startsWith("rgba")) {
    return color.replace(/rgba\(([^)]+)\)/, (_, inner) => {
      const parts = inner.split(",").map((part) => part.trim());
      parts[3] = alpha;
      return `rgba(${parts.join(",")})`;
    });
  }

  if (color.startsWith("rgb")) {
    return color.replace("rgb", "rgba").replace(")", `, ${alpha})`);
  }

  if (color.startsWith("#")) {
    const hex = color.slice(1);
    const normalized = hex.length === 3
      ? hex.split("").map((ch) => ch + ch).join("")
      : hex;
    const intVal = parseInt(normalized, 16);
    const r = (intVal >> 16) & 255;
    const g = (intVal >> 8) & 255;
    const b = intVal & 255;
    return `rgba(${r}, ${g}, ${b}, ${alpha})`;
  }

  return color;
};

const ensureArray = (value) => {
  if (!value) return [];
  return Array.isArray(value) ? value : [value];
};

export const Chart = {
  mounted() {
    const selector = "#" + this.el.id;
    this.chart = echarts.init(this.el.querySelector(selector + "-chart"));
    this._updateChartOptions();

    this._resizeHandler = () => this.chart.resize();
    window.addEventListener("resize", this._resizeHandler);

    this._themeEventHandler = () => this._scheduleThemeRefresh();
    window.addEventListener("phx:set-theme", this._themeEventHandler);

    this._themeObserver = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.attributeName === "data-theme") {
          this._scheduleThemeRefresh();
          break;
        }
      }
    });
    this._themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["data-theme"],
    });
  },

  updated() {
    this._updateChartOptions();
  },

  destroyed() {
    if (this._resizeHandler) {
      window.removeEventListener("resize", this._resizeHandler);
    }

    if (this._themeEventHandler) {
      window.removeEventListener("phx:set-theme", this._themeEventHandler);
      this._themeEventHandler = null;
    }

    if (this._themeRefreshId) {
      cancelAnimationFrame(this._themeRefreshId);
      this._themeRefreshId = null;
    }

    if (this._themeObserver) {
      this._themeObserver.disconnect();
      this._themeObserver = null;
    }
  },

  _updateChartOptions() {
    const selector = "#" + this.el.id;
    const option = JSON.parse(
      this.el.querySelector(selector + "-data").textContent,
    );

    this._applyLabelFormatters(option);

    this._baseOption = cloneOption(option);

    this._applyTheme(option);

    this.chart.setOption(option, true);
  },

  _applyLabelFormatters(option) {
    if (!option.series) return;

    const remainingSeries = option.series.find((s) => s.meta_key === "remaining");
    if (remainingSeries && remainingSeries.label) {
      remainingSeries.label.formatter = function (params) {
        return params.name === "Sem Categoria"
          ? ""
          : "R$" + params.value;
      };
    }

    const goalSeries = option.series.find((s) => s.meta_key === "goal");
    if (goalSeries && goalSeries.label) {
      goalSeries.label.formatter = function (params) {
        return params.name === "Sem Categoria"
          ? ""
          : "R$" + params.value;
      };
    }
  },

  _applyTheme(option) {
    const { text: textColor, surface: surfaceColor, border: borderColor } = readThemePalette();
    const subtleBorder = withAlpha(borderColor, 0.4);
    const subtleText = withAlpha(textColor, 0.65);

    option.textStyle = Object.assign({}, option.textStyle, { color: textColor });

    if (option.legend) {
      option.legend.textStyle = Object.assign(
        {},
        option.legend.textStyle,
        { color: textColor },
      );
    }

    if (option.tooltip) {
      option.tooltip.backgroundColor = surfaceColor;
      option.tooltip.borderColor = borderColor;
      option.tooltip.textStyle = Object.assign(
        {},
        option.tooltip.textStyle,
        { color: textColor },
      );
    }

    const axes = [
      ...ensureArray(option.xAxis),
      ...ensureArray(option.yAxis),
    ];

    axes.forEach((axis) => {
      if (!axis) return;
      axis.axisLabel = Object.assign({}, axis.axisLabel, { color: textColor });
      axis.axisLine = Object.assign({}, axis.axisLine, {
        lineStyle: Object.assign(
          {},
          axis.axisLine?.lineStyle,
          { color: borderColor },
        ),
      });

      if (axis.splitLine) {
        axis.splitLine.lineStyle = Object.assign(
          {},
          axis.splitLine.lineStyle,
          { color: subtleBorder },
        );
      }
    });

    if (option.series) {
      option.series.forEach((series) => {
        if (series.type === "pie") {
          series.label = Object.assign({}, series.label, { color: textColor });
          if (series.labelLine) {
            series.labelLine.lineStyle = Object.assign(
              {},
              series.labelLine.lineStyle,
              { color: subtleText },
            );
          }
          return;
        }

        if (series.meta_key === "goal") {
          series.label = Object.assign({}, series.label, { color: subtleText });
          return;
        }

        if (series.meta_key === "remaining" || series.meta_key === "spent") {
          series.label = Object.assign({}, series.label, { color: "#fff" });
          return;
        }

        if (!series.label || !series.label.color) {
          series.label = Object.assign({}, series.label, { color: textColor });
        }
      });
    }
  },

  _refreshTheme() {
    if (!this._baseOption) return;

    const option = cloneOption(this._baseOption);
    this._applyLabelFormatters(option);
    this._applyTheme(option);
    this.chart.setOption(option, { notMerge: true });
  },

  _scheduleThemeRefresh() {
    if (!this._baseOption || !this.chart) {
      return;
    }

    if (this._themeRefreshId) {
      cancelAnimationFrame(this._themeRefreshId);
    }

    this._themeRefreshId = requestAnimationFrame(() => {
      this._themeRefreshId = null;
      this._refreshTheme();
    });
  },
};
