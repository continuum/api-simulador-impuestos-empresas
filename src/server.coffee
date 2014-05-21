express = require 'express'
simulador = require './simulador'

app = express()

app.get '/simulate', (req, res) ->
  # Params: ventas_anuales, utilidades_anuales, retiros_anuales,
  #         sueldo_mensual_socio, numero_socios,
  #         regimen_especial (14_bis o 14_quater), compartir_anonimamente
  res.send
    impuestos2014: 0,
    deltaReforma:
      'eliminacion14Bis': 7920000
      'eliminacion14Quater': 0
      'aumento5PorCiento': 1980000
      'rentaAtribuida': -2157603
    impuestosConReforma: 7742396
