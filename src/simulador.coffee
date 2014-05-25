_ = require('underscore')

UTM = 41801 # Pesos a Mayo 2014
            # Fuente: http://www.sii.cl/pagina/valores/utm/utm2014.htm
UTA = 12 * UTM
UF = 23931.69 # Pesos al 31 de Mayo 2014
              # Fuente: http://www.sii.cl/pagina/valores/uf/uf2014.htm

TOPE_IMPONIBLE = 72.3 * UF

LIMITE_INGRESOS_14_BIS = 3000 * UTM
LIMITE_INGRESOS_14_QUATER = 28000 * UTM
LIMITE_EXENCION_14_QUATER = 1440 * UTM

class SimuladorImpuestos
  constructor: (opts) ->
    @tasaPrimeraCategoria = opts.tasaPrimeraCategoria
    @tramosImpuestos = _.sortBy(opts.tramosImpuestos, (t) -> t.desde).reverse()
    @regimenesEspeciales = opts.regimenesEspeciales || {}

  sueldoTributable: (sueldoLiquido) ->
    # Se asume un aproximado de 20% de descuentos de AFP + Isapre +
    # Seguro Cesantia y otros sobre tope imponible
    sueldoLiquido - Math.max(sueldoLiquido, TOPE_IMPONIBLE) * 0.2

  retiroBruto: (retiroAnual) ->
    retiroAnual / (1 - @tasaPrimeraCategoria)

  tramoImpuesto: (ingresoAnual) ->
    _.find(@tramosImpuestos, (tramo) -> ingresoAnual > tramo.desde) ||
      _.last(@tramosImpuestos) # Si los ingresos son 0 usar el ultimo
                               # tramo (pues estan ordenados de mayor a
                               # menor)

  impuestoPorTramo: (ingresoAnual) ->
    tramo = @tramoImpuesto(ingresoAnual)
    ingresoAnual * tramo.factor - tramo.rebaja

  impuestoExtraPorRetiros: (retiroAnualSocio, sueldoLiquidoSocio) ->
    retiroBrutoSocio = @retiroBruto(retiroAnualSocio)
    sueldoTributableSocio = @sueldoTributable(sueldoLiquidoSocio)
    # Impuesto global total menos lo pagado por la persona por su sueldo
    # mes a mes, menos lo pagado por la empresa en primera categoria
    # (OJO: Esto asume que todos los retiros pagaron impuesto de primera
    #       categoria)
    globalComplementario =  @impuestoPorTramo(
      12 * sueldoTributableSocio + retiroBrutoSocio
    )
    segundaCategoria = @impuestoPorTramo(12 * sueldoTributableSocio)
    primeraCategoria = retiroBrutoSocio * @tasaPrimeraCategoria
    globalComplementario - primeraCategoria - segundaCategoria

  impactoImpuestosEnCaja: (utilidadesAnuales, retiroAnualSocio,
                           sueldoLiquidoSocio, cantidadSocios,
                           regimenEspecial) ->
    impacto =
      porTasaPrimeraCategoria: utilidadesAnuales * @tasaPrimeraCategoria,
      porRetiros:  cantidadSocios * @impuestoExtraPorRetiros(
        retiroAnualSocio, sueldoLiquidoSocio
      )
    impactoRegimenesEspeciales =
      if regimenEspecial of @regimenesEspeciales
        @regimenesEspeciales[regimenEspecial](
          utilidadesAnuales, retiroAnualSocio, sueldoLiquidoSocio,
          cantidadSocios, this
        )
      else
        {}
    _.extend impacto, impactoRegimenesEspeciales

class SimuladorImpuestosConRentaAtribuida extends SimuladorImpuestos
  impactoImpuestosEnCaja: (utilidadesAnuales, retiroAnualSocio,
                           sueldoLiquidoSocio, cantidadSocios,
                           regimenEspecial) ->
    # En el sistema reformado se atribuyen directamente las utilidades
    # de los socios tal como si las hubieran retirado. Por tanto,
    # acá descartamos el monto efectivamente retirado por los socios
    # asumimos que se distribuye el total de la utilidad:
    super(utilidadesAnuales, utilidadesAnuales / cantidadSocios,
          sueldoLiquidoSocio, cantidadSocios, regimenEspecial)


simulador2014 = new SimuladorImpuestos
  tasaPrimeraCategoria: 0.2

  tramosImpuestos: [
    # http://www.sii.cl/aprenda_sobre_impuestos/impuestos/imp_directos.htm
    {desde:  0,          factor: 0,     rebaja:  0          },
    {desde:  13.5 * UTA, factor: 0.04,  rebaja:  0.54 * UTA },
    {desde:  30   * UTA, factor: 0.08,  rebaja:  1.74 * UTA },
    {desde:  50   * UTA, factor: 0.135, rebaja:  4.49 * UTA },
    {desde:  70   * UTA, factor: 0.23,  rebaja: 11.14 * UTA },
    {desde:  90   * UTA, factor: 0.304, rebaja: 17.8  * UTA },
    {desde: 120   * UTA, factor: 0.355, rebaja: 23.92 * UTA },
    {desde: 150   * UTA, factor: 0.40,  rebaja: 30.67 * UTA }
  ]
  regimenesEspeciales:
    '14bis': (utilidadesAnuales, retiroAnualSocio, sueldoLiquidoSocio,
              cantidadSocios, sim) ->
      # El efecto practico del 14bis es evitar la tasa de primera
      # categoria para las utilidades NO retiradas
      utilidadesRetiradas = cantidadSocios * retiroAnualSocio
      utilidadesReinvertidas = utilidadesAnuales - utilidadesRetiradas
      por14Bis: -(utilidadesReinvertidas * sim.tasaPrimeraCategoria)


    '14quater': (utilidadesAnuales, retiroAnualSocio, sueldoLiquidoSocio,
                 cantidadSocios, sim) ->
      # El efecto practico del 14quater es evitar la tasa de primera
      # categoria para utilidades NO retiradas con un tope de
      # 1440 UTM
      utilidadesRetiradas = cantidadSocios * retiroAnualSocio
      utilidadesReinvertidas = utilidadesAnuales - utilidadesRetiradas
      exencion = Math.min(utilidadesReinvertidas, LIMITE_EXENCION_14_QUATER)
      por14Quater: -(exencion * sim.tasaPrimeraCategoria)

simuladorConReforma = new SimuladorImpuestosConRentaAtribuida
  tasaPrimeraCategoria: 0.25

  tramosImpuestos: [
    {desde:  0,          factor: 0,     rebaja:  0          },
    {desde:  13.5 * UTA, factor: 0.04,  rebaja:  0.54 * UTA },
    {desde:  30   * UTA, factor: 0.08,  rebaja:  1.74 * UTA },
    {desde:  50   * UTA, factor: 0.135, rebaja:  4.49 * UTA },
    {desde:  70   * UTA, factor: 0.23,  rebaja: 11.14 * UTA },
    {desde:  90   * UTA, factor: 0.304, rebaja: 17.8  * UTA },
    # De acuerdo al proyecto de ley se baja el factor maximo al 35%
    # y se ajusta la rebaja acorde al nuevo factor:
    {desde: 120   * UTA, factor: 0.35, rebaja: 23.32 * UTA },
  ]



module.exports =
  SimuladorImpuestos: SimuladorImpuestos
  simulador2014: simulador2014
  simuladorConReforma: simuladorConReforma
