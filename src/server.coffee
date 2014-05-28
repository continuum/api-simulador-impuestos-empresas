express = require 'express'
cors = require 'cors'
simulador = require './simulador'

app = express()
app.use cors()

app.get '/simulate', (req, res) ->
  # Params: ventas_anuales, utilidades_anuales, retiro_anual_socio,
  #         sueldo_mensual_socio, numero_socios,
  #         regimen_especial (14bis o 14quater), compartir_anonimamente
  ventasAnuales = parseInt req.param('ventas_anuales')
  utilidadesAnuales = parseInt req.param('utilidades_anuales')
  retiroAnualSocio = parseInt req.param('retiro_anual_socio')
  sueldoMensualSocio = parseInt req.param('sueldo_mensual_socio')
  numeroSocios = parseInt req.param('numero_socios')
  regimenEspecial = req.param('regimen_especial')

  impacto2014 = simulador.simulador2014.impactoImpuestosEnCaja(
    utilidadesAnuales, retiroAnualSocio, sueldoMensualSocio,
    numeroSocios, regimenEspecial
  )
  impactoConReforma = simulador.simuladorConReforma.impactoImpuestosEnCaja(
    utilidadesAnuales, retiroAnualSocio, sueldoMensualSocio,
    numeroSocios, regimenEspecial
  )
  res.send
    impacto2014: impacto2014,
    impactoConReforma: impactoConReforma

server = app.listen process.env.PORT || 3000, ->
  console.log 'Listening on port %d', server.address().port
