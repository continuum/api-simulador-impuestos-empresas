express = require 'express'
cors = require 'cors'
mongo = require 'mongodb'
crypto = require 'crypto'
_ = require 'underscore'
simulador = require './simulador'

app = express()
app.use cors()

sha256 = (data) ->
  hash = crypto.createHash('sha256')
  hash.update(data)
  hash.digest('hex')

record = (req) ->
  mongoUri = process.env.MONGOLAB_URI || process.env.MONGOHQ_URL ||
    'mongodb://localhost/simulador-impuestos';
  mongo.Db.connect mongoUri, (err, db) ->
    db.collection 'simulaciones', (er, collection) ->
      data = _.extend(req.query, hashed_ip: sha256(req.ip))
      collection.insert(data, safe: true, (er,rs) -> )

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
  record(req) if req.param('compartir_anonimamente') == 'true'
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
