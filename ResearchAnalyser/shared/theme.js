/* ============================================================================
   ResearchAnalyser · apariencia de los gráficos Plotly
   ----------------------------------------------------------------------------
   Solo apariencia. Envuelve Plotly.newPlot y Plotly.react para aplicar una
   plantilla visual común (tipografía Inter, rejilla suave, paleta USACH y
   barras con esquinas redondeadas). Los datos, cálculos y disposiciones que
   definen los módulos no se modifican: la plantilla solo rellena lo que cada
   gráfico no especifica.
   ============================================================================ */
(() => {
  if (typeof Plotly === 'undefined') return;
  const module = document.body.dataset.module;
  // Paleta oficial USACH (Manual de Normas Gráficas 2024 2S, 1.7): principales y PEI 2030
  const teal = '#00A499', orange = '#E77500', gray = '#394049', blue = '#498BCA', purple = '#8C4799', yellow = '#EAAA00', red = '#C8102E';
  const colorway = module === 'tesis'
    ? [orange, teal, blue, purple, yellow, gray, red, '#F2A65A', '#55B9B0', '#9CC7EC']
    : [teal, orange, blue, purple, yellow, gray, red, '#55B9B0', '#F2A65A', '#9CC7EC'];
  // Paleta categórica del módulo de publicaciones (flujo de áreas): misma paleta oficial
  if (typeof CAT !== 'undefined' && Array.isArray(CAT)) {
    [teal, orange, blue, purple, yellow, gray, red, '#55B9B0', '#F2A65A', '#9CC7EC'].forEach((c, i) => { CAT[i] = c; });
  }
  const axis = {
    gridcolor: '#ECF0F2', zerolinecolor: '#E1E6E9', linecolor: '#E1E6E9',
    tickfont: { family: 'Inter, system-ui, sans-serif', size: 13, color: '#5B6670' },
    title: { font: { family: 'Inter, system-ui, sans-serif', size: 13.5, color: '#5B6670' } },
    automargin: true
  };
  const template = {
    layout: {
      font: { family: 'Inter, system-ui, sans-serif', size: 13.5, color: '#262E35' },
      colorway,
      paper_bgcolor: 'rgba(0,0,0,0)',
      plot_bgcolor: 'rgba(0,0,0,0)',
      hoverlabel: {
        bgcolor: '#262E35', bordercolor: '#262E35',
        font: { family: 'Inter, system-ui, sans-serif', size: 13.5, color: '#FFFFFF' },
        align: 'left'
      },
      xaxis: axis, yaxis: axis,
      legend: { font: { family: 'Inter, system-ui, sans-serif', size: 13, color: '#5B6670' }, bgcolor: 'rgba(0,0,0,0)' },
      hovermode: 'closest',
      barcornerradius: 6
    },
    data: {
      bar: [{ marker: { cornerradius: 6, line: { width: 0 } } }],
      scatter: [{ marker: { line: { width: 0 } } }]
    }
  };
  function dress(layout, config) {
    const next = Object.assign({}, layout || {});
    if (!next.template) next.template = template;
    const cfg = Object.assign({ displaylogo: false }, config || {});
    return [next, cfg];
  }
  const newPlot = Plotly.newPlot, react = Plotly.react;
  Plotly.newPlot = function (gd, data, layout, config) {
    if (Array.isArray(data) || data === undefined) { const [l, c] = dress(layout, config); return newPlot.call(Plotly, gd, data, l, c); }
    return newPlot.apply(Plotly, arguments);
  };
  Plotly.react = function (gd, data, layout, config) {
    if (Array.isArray(data) || data === undefined) { const [l, c] = dress(layout, config); return react.call(Plotly, gd, data, l, c); }
    return react.apply(Plotly, arguments);
  };
})();
