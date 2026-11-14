// Plantilla de app para TV: navegación con las flechas del mando, OK para activar y Atrás para salir.
(function () {
  'use strict';

  var TECLAS = { IZQ: 37, ARR: 38, DER: 39, ABA: 40, OK: 13, ATRAS: 10009, ESC: 27 };
  var COLUMNAS = 2;
  var tarjetas = Array.prototype.slice.call(document.querySelectorAll('.tarjeta'));
  var panel = document.getElementById('panel');
  var indice = 0;
  var contador = 0;
  var temporizador = null;
  var colores = ['#1e3a8a', '#065f46', '#7c2d12', '#581c87'];
  var color = 0;

  function enfocar(i) {
    indice = Math.max(0, Math.min(tarjetas.length - 1, i));
    tarjetas[indice].focus();
  }

  function mostrar(texto) { panel.textContent = texto; }

  var acciones = {
    reloj: function () {
      clearInterval(temporizador);
      var tic = function () { mostrar('Hora actual: ' + new Date().toLocaleTimeString()); };
      tic();
      temporizador = setInterval(tic, 1000);
    },
    contador: function () { clearInterval(temporizador); contador++; mostrar('Has pulsado ' + contador + ' veces.'); },
    color: function () { color = (color + 1) % colores.length; document.body.style.background = colores[color]; mostrar('Color de fondo cambiado.'); },
    info: function () {
      clearInterval(temporizador);
      var tizen_ = typeof tizen !== 'undefined';
      mostrar('Resolución: ' + window.innerWidth + 'x' + window.innerHeight + ' · API Tizen: ' + (tizen_ ? 'disponible' : 'no disponible'));
    }
  };

  tarjetas.forEach(function (t, i) {
    t.addEventListener('click', function () { enfocar(i); acciones[t.dataset.accion](); });
  });

  function salir() {
    try { tizen.application.getCurrentApplication().exit(); } catch (e) { mostrar('Salir solo funciona en el televisor.'); }
  }

  document.addEventListener('keydown', function (e) {
    switch (e.keyCode) {
      case TECLAS.IZQ: enfocar(indice - 1); break;
      case TECLAS.DER: enfocar(indice + 1); break;
      case TECLAS.ARR: enfocar(indice - COLUMNAS); break;
      case TECLAS.ABA: enfocar(indice + COLUMNAS); break;
      case TECLAS.OK: tarjetas[indice].click(); break;
      case TECLAS.ATRAS: case TECLAS.ESC: salir(); break;
      default: return;
    }
    e.preventDefault();
  });

  window.addEventListener('load', function () { enfocar(0); });
})();
