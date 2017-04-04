# -*- coding: utf-8 -*-
"""
/***************************************************************************
 KPOpilotDockWidget
                                 A QGIS plugin
 Knooppunten Datasysteem
                             -------------------
        begin                : 2016-12-19
        git sha              : $Format:%H$
        copyright            : (C) 2017 by Jorge Gil
        email                : gil.jorge@gmail.com
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
"""


from qgis.core import *
from qgis.gui import *


class KPOExplorer:

    def __init__(self, iface, dockwidget, plugin_dir):

        self.iface = iface
        self.dlg = dockwidget
        self.plugin_dir = plugin_dir
        self.canvas = self.iface.mapCanvas()
        self.legend = self.iface.legendInterface()

        # prepare the project and workspace
        self.dlg.visibilityChanged.connect(self.onShow)
        self.data_layers = {}

        # connect signals from th UI
        self.dlg.tabChanged.connect(self.loadTabLayers)
        # knooppunten
        self.dlg.scenarioChanged.connect(self.setScenarioLayers)
        self.dlg.scenarioShow.connect(self.showScenario)
        self.dlg.isochronesShow.connect(self.showIsochrones)
        self.dlg.todLevelChanged.connect(self.setScenarioLayers)
        self.dlg.knooppuntChanged.connect(self.setKnooppuntenAttribute)
        self.dlg.knooppuntShow.connect(self.showKnooppunten)
        self.dlg.knooppuntSelected.connect(self.zoomToKnooppunt)
        self.dlg.knooppuntDeselected.connect(self.zoomOutKnooppunt)
        # verstedelijking
        self.dlg.onderbenutShow.connect(self.showOnderbenutLocaties)
        self.dlg.intensityTypeChanged.connect(self.setIntensityLevel)
        self.dlg.intensityShow.connect(self.showIntensity)
        self.dlg.intensityLevelChanged.connect(self.setIntensityLevel)
        self.dlg.accessibilityShow.connect(self.showPTAL)
        self.dlg.accessibilityLevelChanged.connect(self.setPTALLevel)
        self.dlg.planTypeChanged.connect(self.setPlanType)
        self.dlg.planShow.connect(self.showPlan)
        self.dlg.planSelected.connect(self.zoomToPlan)
        self.dlg.planDeselected.connect(self.zoomOutPlan)
        # afvangstations
        self.dlg.stationAttributeChanged.connect(self.setStationAttribute)
        self.dlg.stationShow.connect(self.showStation)
        self.dlg.stationSelected.connect(self.zoomToStation)
        self.dlg.stationDeselected.connect(self.zoomOutStation)
        self.dlg.locationTypeChanged.connect(self.setLocationType)
        self.dlg.locationShow.connect(self.showLocation)
        self.dlg.locationSelected.connect(self.zoomToLocation)
        self.dlg.locationDeselected.connect(self.zoomOutLocation)
        # mobiliteit
        self.dlg.isochroneWalkShow.connect(self.showWalkIsochrones)
        self.dlg.isochroneBikeShow.connect(self.showBikeIsochrones)
        self.dlg.isochroneOVShow.connect(self.showOVIsochrones)
        self.dlg.ptalChanged.connect(self.setAccessibility)
        self.dlg.ptalShow.connect(self.showAccessibility)
        self.dlg.frequencyChanged.connect(self.setStopFrequency)
        self.dlg.stopsChanged.connect(self.setStopTypes)
        self.dlg.stopsShow.connect(self.showStopFrequency)
        self.dlg.stopsSelected.connect(self.zoomToStop)
        self.dlg.stopsDeselected.connect(self.zoomOutStop)

        # constants
        self.onderbenutLabels = {
            'ptal': ['Minimaal PTAL: 1a - Very poor (0.01 tot 2.5)',
                     'Minimaal PTAL: 1b - Very poor (2.5 tot 5)',
                     'Minimaal PTAL: 2 - Poor (5 tot 10)',
                     'Minimaal PTAL: 3 - Moderate (10 tot 15)',
                     'Minimaal PTAL: 4 - Good (15 tot 20)',
                     'Minimaal PTAL: 5 - Very Good (20 tot 25)',
                     'Minimaal PTAL: 6a - Excellent (25 tot 40)',
                     'Minimaal PTAL: 6b - Excellent (40 of meer)'],
            'huishoudens': ['Minder dan 10 huishoudens per hectare',
                            'Minder dan 20 huishoudens per hectare',
                            'Minder dan 40 huishoudens per hectare',
                            'Minder dan 60 huishoudens per hectare',
                            'Minder dan 80 huishoudens per hectare',
                            'Minder dan 100 huishoudens per hectare'],
            'intensiteit': ['Minder dan 25 personen per hectare',
                            'Minder dan 50 personen per hectare',
                            'Minder dan 100 personen per hectare',
                            'Minder dan 200 personen per hectare',
                            'Minder dan 400 personen per hectare',
                            'Minder dan 800 personen per hectare'],
            'fysieke_dichtheid': ['Minder dan 0.1 FSI',
                                  'Minder dan 0.4 FSI',
                                  'Minder dan 0.7 FSI',
                                  'Minder dan 1.0 FSI',
                                  'Minder dan 1.5 FSI',
                                  'Minder dan 2.0 FSI'],
            'woz_waarde': ['Minder dan 150k WOZ',
                           'Minder dan 200k WOZ',
                           'Minder dan 300k WOZ',
                           'Minder dan 500k WOZ',
                           'Minder dan 750k WOZ',
                           'Minder dan 1000k WOZ']
        }
        self.onderbenutLevels = {
            'ptal': ['(\'1a\', \'1b\', \'2\', \'3\', \'4\', \'5\', \'6a\', \'6b\')',
                     '(\'1b\', \'2\', \'3\', \'4\', \'5\', \'6a\', \'6b\')',
                     '(\'2\', \'3\', \'4\', \'5\', \'6a\', \'6b\')',
                     '(\'3\', \'4\', \'5\', \'6a\', \'6b\')',
                     '(\'4\', \'5\', \'6a\', \'6b\')',
                     '(\'5\', \'6a\', \'6b\')',
                     '(\'6a\', \'6b\')',
                     '(\'6b\')'],
            'huishoudens': [10, 20, 40, 60, 80, 100],
            'intensiteit': [25, 50, 100, 200, 400, 800],
            'fysieke_dichtheid': [0.1, 0.4, 0.7, 1.0, 1.5, 2.0],
            'woz_waarde': [150, 200, 300, 500, 750, 1000]
        }
        # globals
        self.intensity_level = '"huishoudens" < 100'
        self.ptal_level = '"ov_bereikbaarheidsniveau" in (\'1a\', \'1b\', \'2\', \'3\', \'4\', \'5\', \'6a\', \'6b\')'
        self.binen_regios = []
        self.buiten_regios = []
        self.station_ov_routes = ''
        self.afvangstation = ''
        self.location = ''
        self.selected_stop = ''

    ###
    # General
    def onShow(self, onoff):
        if onoff:
            # reset all the default configurations
            self.dlg.resetDefaults()
            # show intro tab
            self.dlg.resetQuestionTab()
            # load the project file with all the data layers
            project_path = self.plugin_dir + '/data/kpo_datasysteem.qgs'
            self.iface.addProject(project_path)
            # activate map tips for info window
            maptips = self.iface.actionMapTips()
            if not maptips.isChecked():
                maptips.setChecked(True)
            # activate pan
            self.iface.actionPan().trigger()
            # populate the dictionary with all the layers for use throughout
            self.data_layers = {}
            for layer in self.iface.legendInterface().layers():
                self.data_layers[layer.name()] = layer

    def loadTabLayers(self, tab_id):
        # hide all groups
        for i in range(0, 5):
            self.legend.setGroupVisible(i, False)
            self.legend.setGroupExpanded(i, False)
        # self.setLayerVisible('Treinstations', True)
        # show only selected group
        if tab_id == 2:
            self.loadKnooppuntenLayers()
            self.legend.setGroupExpanded(2, True)
        elif tab_id == 3:
            self.loadVerstedelijkingLayers()
            self.legend.setGroupExpanded(3, True)
        elif tab_id == 4:
            self.loadVerbindingenLayers()
            self.legend.setGroupExpanded(4, True)
        elif tab_id == 1:
            self.loadMobiliteitLayers()
            self.legend.setGroupExpanded(1, True)

    def loadForegroundLayers(self, onoff):
        self.legend.setGroupVisible(0, onoff)

    ###
    # Knooppunten
    def loadKnooppuntenLayers(self):
        self.loadForegroundLayers(True)
        self.setLayerVisible('Treinstations (achtergrond)', True)
        # scenario layers
        self.setScenarioLayers()
        self.showScenario(self.dlg.isScenarioVisible())
        # isochrone layers
        self.showIsochrones(self.dlg.isIsochronesVisible())
        # knooppunten layers
        self.showKnooppunten(self.dlg.isKnooppuntVisible())

    # Scenario methods
    def showScenario(self, onoff):
        self.setLayerVisible('Woonscenarios', onoff)
        self.setLayerVisible('Buiten invloedsgebied', onoff)
        # expand layer to show legend icons
        self.setLayerExpanded('Woonscenarios', onoff)
        self.loadForegroundLayers(onoff)
        if onoff:
            self.setCurrentLayer('Woonscenarios')

    def setScenarioLayers(self):
        current_scenario = self.dlg.getScenario()
        current_tod = self.dlg.getTODLevel()
        # update housing scenarios layer
        self.setFilterExpression('Woonscenarios', '"scenario_naam" = \'%s\'' % current_scenario)
        if current_scenario == 'Huidige situatie':
            self.setLayerStyle('Woonscenarios', 'woon_huidige_huishouden')
        else:
            self.setLayerStyle('Woonscenarios', 'woon_nieuwe_huishouden')
        self.setCurrentLayer('Woonscenarios')
        # update knooppunten scenarios layer
        expression = '"scenario_naam" = \'%s\' AND "tod_beleidsniveau" = %d' % (current_scenario, current_tod)
        if current_scenario != 'Huidige situatie':
            self.setFilterExpression('Treinstations scenarios', expression)
        # update scenario summary
        self.setFilterExpression('Overzicht woonscenarios', expression)
        summary_values = []
        fields = ('verwachte_huishoudens', 'op_loopafstand', 'op_fietsafstand', 'buiten_invloedsgebied')
        feature_values = self.getFeatureValues('Overzicht woonscenarios', fields)
        # get first result, should be only one
        for values in feature_values.itervalues():
            summary_values = values
            break
        self.dlg.updateScenarioSummary(summary_values)
        # update knooppunten
        if self.dlg.isKnooppuntVisible():
            self.showKnooppunten(True)
        self.setKnooppuntenAttribute()

    def showIsochrones(self, onoff):
        #self.setFilterExpression('Loopafstand (800 m)', '"modaliteit"=\'walk\'')
        self.setLayerVisible('Loopafstand (800 m)', onoff)
        #self.setFilterExpression('Fietsafstand (3000 m)', '"modaliteit"=\'fiets\'')
        self.setLayerVisible('Fietsafstand (3000 m)', onoff)

    # Knooppunten methods
    def showKnooppunten(self, onoff):
        current_scenario = self.dlg.getScenario()
        if onoff:
            self.setLayerVisible('Treinstations (voorgrond)', False)
            if current_scenario == 'Huidige situatie':
                self.setLayerVisible('Treinstations', True)
                self.setLayerExpanded('Treinstations', True)
                self.setLayerVisible('Treinstations scenarios', False)
                self.setLayerExpanded('Treinstations scenarios', False)
                self.setCurrentLayer('Treinstations')
            else:
                self.setLayerVisible('Treinstations', False)
                self.setLayerExpanded('Treinstations', False)
                self.setLayerVisible('Treinstations scenarios', True)
                self.setLayerExpanded('Treinstations scenarios', True)
                self.setCurrentLayer('Treinstations scenarios')
        else:
            self.setLayerVisible('Treinstations (voorgrond)', True)
            self.setLayerVisible('Treinstations', False)
            self.setLayerExpanded('Treinstations', False)
            self.setLayerVisible('Treinstations scenarios', False)
            self.setLayerExpanded('Treinstations scenarios', False)
            self.setCurrentLayer('Woonscenarios')

    def setKnooppuntenAttribute(self):
        # identify scenario layer to use
        current_scenario = self.dlg.getScenario()
        current_attribute = self.dlg.getKnooppuntKenmerk()
        if current_scenario == 'Huidige situatie':
            knooppunt_layer = 'Treinstations'
        else:
            knooppunt_layer = 'Treinstations scenarios'
        self.setCurrentLayer(knooppunt_layer)
        # apply relevant style and prepare table
        fields = ['halte_naam']
        headers = ['Station']
        if current_attribute == 'In- en uitstappers trein':
            fields.append('in_uit_trein')
            headers.append('Totaal')
            self.setLayerStyle(knooppunt_layer, '%s_%s' % (knooppunt_layer.lower(), 'in_uit_trein'))
        elif current_attribute == 'In- en uitstappers BTM':
            fields.append('in_uit_btm')
            headers.append('Totaal')
            self.setLayerStyle(knooppunt_layer, '%s_%s' % (knooppunt_layer.lower(), 'in_uit_btm'))
        elif current_scenario == 'Huidige situatie' and current_attribute == 'OV fietsen':
            fields.append('ov_fietsen')
            headers.append('Totaal')
            self.setLayerStyle(knooppunt_layer, '%s_%s' % (knooppunt_layer.lower(), 'ov_fietsen'))
        elif current_attribute == 'Fiets bezetting %':
            fields.extend(['fiets_plaatsen', 'fiets_bezetting'])
            headers.extend(['Plaatsen', 'Bezetting %'])
            self.setLayerStyle(knooppunt_layer, '%s_%s' % (knooppunt_layer.lower(), 'fiets_bezetting'))
        elif current_attribute == 'P+R bezetting %':
            fields.extend(['pr_plaatsen', 'pr_bezetting'])
            headers.extend(['Plaatsen', 'Bezetting %'])
            self.setLayerStyle(knooppunt_layer, '%s_%s' % (knooppunt_layer.lower(), 'pr_bezetting'))
        # whenever there's a change at this level, update the values table
        if knooppunt_layer == 'Treinstations scenarios':
            fields.append('procent_knoop_verandering')
            headers.append('% verandering')
        feature_values = self.getFeatureValues(knooppunt_layer, fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateKnooppuntenTable(headers, values)
        # clear isochrone filters
        #self.setFilterExpression('Loopafstand (800 m)', '"modaliteit"=\'walk\'')
        #self.setFilterExpression('Fietsafstand (3000 m)', '"modaliteit"=\'fiets\'')

    def zoomToKnooppunt(self, node_name):
        expression = ' AND "halte_naam"=\'%s\'' % node_name
        # show isochrones for that station only
        self.setFilterExpression('Loopafstand (800 m)', '"modaliteit"=\'walk\'%s' % expression)
        self.setFilterExpression('Fietsafstand (3000 m)', '"modaliteit"=\'fiets\'%s' % expression)
        # zoom to fiets isochrone extent
        self.setExtentToLayer('Fietsafstand (3000 m)')

    def zoomOutKnooppunt(self):
        # show isochrones for that station only
        self.setFilterExpression('Loopafstand (800 m)', '"modaliteit"=\'walk\'')
        self.setFilterExpression('Fietsafstand (3000 m)', '"modaliteit"=\'fiets\'')
        # zoom to fiets isochrone extent
        self.setExtentToLayer('Fietsafstand (3000 m)')

    ###
    # Verstedelijking
    def loadVerstedelijkingLayers(self):
        self.setLayerVisible('Treinstations (achtergrond)', True)
        self.showOnderbenutLocaties(self.dlg.isLocatiesVisible())
        # Intensity
        self.setIntensityLevel()
        self.showIntensity(self.dlg.isIntensityVisible())
        # Accessibility
        self.setPTALLevel()
        self.showPTAL(self.dlg.isAccessibilityVisible())
        # Plans
        self.setPlanType()
        self.showPlan(self.dlg.isPlanVisible())

    def showOnderbenutLocaties(self, onoff):
        self.setLayerVisible('Onderbenute bereikbare locaties', False)
        if onoff:
            if not self.dlg.isIntensityVisible() and not self.dlg.isAccessibilityVisible():
                self.setLayerVisible('Onderbenute bereikbare locaties', onoff)
                self.setCurrentLayer('Onderbenute bereikbare locaties')

    # Intensity methods
    def showIntensity(self, onoff):
        self.setLayerVisible('Ruimtelijke kenmerken', onoff)
        self.setLayerExpanded('Ruimtelijke kenmerken', onoff)
        self.showOnderbenutLocaties(not onoff)
        if onoff:
            self.setCurrentLayer('Ruimtelijke kenmerken')

    def setIntensityLevel(self):
        intensity_level = self.dlg.getIntensityLevel()
        intensity_type = self.dlg.getIntensityType()
        label = ''
        expression = ''
        style = ''
        # get relevant level values
        if intensity_type == 'Huishoudens':
            label = self.onderbenutLabels['huishoudens'][intensity_level]
            if intensity_level < 6:
                expression = '"huishoudens" < %s' % self.onderbenutLevels['huishoudens'][intensity_level]
            style = 'verstedelijking_huishoudens'
        elif intensity_type == 'Intensiteit (inwoners, werknemer, studenten)':
            label = self.onderbenutLabels['intensiteit'][intensity_level]
            if intensity_level < 6:
                expression = '"intensiteit" < %s' % self.onderbenutLevels['intensiteit'][intensity_level]
            style = 'verstedelijking_intensiteit'
        elif intensity_type == 'Fysieke dichtheid (FSI)':
            label = self.onderbenutLabels['fysieke_dichtheid'][intensity_level]
            if intensity_level < 6:
                expression = '"fysieke_dichtheid" < %s' % self.onderbenutLevels['fysieke_dichtheid'][intensity_level]
            style = 'verstedelijking_dichtheid'
        elif intensity_type == 'WOZ waarde':
            label = self.onderbenutLabels['woz_waarde'][intensity_level]
            if intensity_level < 6:
                expression = '"woz_waarde" > 0 AND "woz_waarde" < %s' % self.onderbenutLevels['woz_waarde'][intensity_level]
            style = 'verstedelijking_woz'
        # update dialog label
        self.dlg.updateIntensityLabel(label)
        # update layers
        self.setFilterExpression('Ruimtelijke kenmerken', expression)
        self.setLayerStyle('Ruimtelijke kenmerken', style)
        self.intensity_level = expression
        self.identifySpatialPotential()
        self.updatePlanTable()

    # Accessibility methods
    def showPTAL(self, onoff):
        self.setLayerVisible('PTAL', onoff)
        self.setLayerExpanded('PTAL', onoff)
        self.showOnderbenutLocaties(not onoff)
        if onoff:
            self.setCurrentLayer('PTAL')

    def setPTALLevel(self):
        ptal_level = self.dlg.getAccessibilityLevel()
        # get relevant level values
        label = self.onderbenutLabels['ptal'][ptal_level]
        expression = '"ov_bereikbaarheidsniveau" in %s' % self.onderbenutLevels['ptal'][ptal_level]
        # update dialog label
        self.dlg.updateAccessibilityLabel(label)
        # update layers
        self.setFilterExpression('PTAL', expression)
        self.ptal_level = expression
        self.identifySpatialPotential()

    def identifySpatialPotential(self):
        expression = ''
        if self.ptal_level and self.intensity_level:
            expression = '%s AND %s' % (self.ptal_level, self.intensity_level)
        elif self.ptal_level:
            expression = self.ptal_level
        elif self.intensity_level:
            expression = self.intensity_level
        self.setFilterExpression('Onderbenute bereikbare locaties', expression)
        self.calculateIntersections()

    # Plan location methods
    def showPlan(self, onoff):
        self.setLayerVisible('Ontwikkellocaties', onoff)
        self.setLayerExpanded('Ontwikkellocaties', onoff)
        if onoff:
            self.setCurrentLayer('Ontwikkellocaties')

    def setPlanType(self):
        plan_type = self.dlg.getPlanType()
        # update map
        style = ''
        expression = ''
        # get main columns
        if plan_type == 'Woningbouwafspraken 2020':
            expression = '"plan_naam" = \'%s\'' % plan_type
            style = 'verstedelijking_RAP'
        elif plan_type == 'Tekort aan plannen 2020':
            expression = '"plan_naam" = \'%s\'' % plan_type
            style = 'verstedelijking_RAP'
        elif plan_type == 'Plancapaciteit':
            expression = '"plan_naam" = \'%s\' AND "plaatsnaam" IS NOT NULL' % plan_type
            style = 'verstedelijking_plancapaciteit'
        elif plan_type == 'Kantorenleegstand':
            expression = '"plan_naam" = \'%s\' AND "plaatsnaam" IS NOT NULL' % plan_type
            style = 'verstedelijking_plancapaciteit'
        # update the map layer
        self.setFilterExpression('Ontwikkellocaties', expression)
        self.setLayerStyle('Ontwikkellocaties', style)
        # self.setExtentToLayer('Ontwikkellocaties')
        # calculate households
        self.calculateIntersections()
        # update table
        self.updatePlanTable()

    def updatePlanTable(self):
        plan_type = self.dlg.getPlanType()
        intensity_type = self.dlg.getIntensityType()
        # update map
        headers = []
        fields = []
        # get main columns
        if plan_type == 'Woningbouwafspraken 2020':
            fields = ['gemeente', 'geplande_woningen']
            headers = ['Gemeente/Regio', 'Woningen']
        elif plan_type == 'Tekort aan plannen 2020':
            fields = ['gemeente', 'geplande_woningen', 'bestaande_woningen', 'net_nieuwe_woningen']
            headers = ['Gemeente/Regio', 'Afspraken', 'Plancapaciteit', 'Verschil']
        elif plan_type == 'Plancapaciteit':
            fields = ['plaatsnaam', 'geplande_woningen']
            headers = ['Plaatsnaam', 'Won.']
        elif plan_type == 'Kantorenleegstand':
            fields = ['plaatsnaam', 'vlakte', 'geplande_woningen']
            headers = ['Plaatsnaam', 'm2', 'Won.']
        # get extra columns
        if plan_type in ('Plancapaciteit', 'Kantorenleegstand'):
            # get column depending on benutting type
            if intensity_type == 'Huishoudens':
                fields.append('gemiddelde_huishoudens')
                headers.append('Huish.')
            elif intensity_type == 'Intensiteit (inwoners, werknemer, studenten)':
                fields.append('gemiddelde_intensiteit')
                headers.append('Intens.')
            elif intensity_type == 'Fysieke dichtheid (FSI)':
                fields.append('gemiddelde_dichtheid')
                headers.append('FSI')
            elif intensity_type == 'WOZ waarde':
                fields.append('gemiddelde_woz')
                headers.append('WOZ')
            # always include PTAL
            fields.append('gemiddelde_bereikbaarheidsindex')
            headers.append('PTAL')
        # update table
        self.setCurrentLayer('Ontwikkellocaties')
        feature_values = self.getFeatureValues('Ontwikkellocaties', fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updatePlanTable(headers, values)

    def calculateIntersections(self):
        # get all relevant cell attributes
        cell_ids = []
        gemeente = []
        cell_attributes = self.getFeatureValues('Onderbenute bereikbare locaties', ['cell_id', 'gemeente'])
        for values in cell_attributes.itervalues():
            cell_ids.append(values[0])
            gemeente.append(values[1])
        # make unique gemeente names
        gemeente = list(set(gemeente))
        # update intersection attribute
        plan_type = self.dlg.getPlanType()
        base_layer = self.data_layers['Ontwikkellocaties']
        # calculate summary
        houses_in = 0
        houses_out = 0
        base_features = base_layer.getFeatures()
        self.binen_regios = []
        self.buiten_regios = []
        if plan_type in ('Woningbouwafspraken 2020', 'Tekort aan plannen 2020'):
            # set plans that have gemeente in list to true
            for feature in base_features:
                if feature.attribute('gemeente') in gemeente:
                    houses_in += feature.attribute('geplande_woningen')
                    self.binen_regios.append(feature.attribute('gemeente'))
                else:
                    houses_out += feature.attribute('geplande_woningen')
                    self.buiten_regios.append(feature.attribute('gemeente'))
        elif plan_type in ('Plancapaciteit', 'Kantorenleegstand'):
            # set plans that have cell id in list to true
            for feature in base_features:
                ids = feature.attribute('cell_ids')
                if ids:
                    ids = ids.split(",")
                    if any(i in cell_ids for i in ids):
                        houses_in += feature.attribute('geplande_woningen')
                        self.binen_regios.append(feature.attribute('plaatsnaam'))
                    else:
                        houses_out += feature.attribute('geplande_woningen')
                        self.buiten_regios.append(feature.attribute('plaatsnaam'))
                else:
                    houses_out += feature.attribute('geplande_woningen')
                    self.buiten_regios.append(feature.attribute('plaatsnaam'))
        # update summary
        total_houses = houses_in + houses_out
        self.dlg.updatePlanSummary([total_houses, houses_in, houses_out])
        # filter plans

    def zoomToPlan(self, plan_name):
        plan_type = self.dlg.getPlanType()
        if plan_type in ('Woningbouwafspraken 2020', 'Tekort aan plannen 2020'):
            self.setFeatureSelection('Ontwikkellocaties', 'gemeente', plan_name)
            self.setExtentToSelection('Ontwikkellocaties')
        elif plan_type in ('Plancapaciteit', 'Kantorenleegstand'):
            self.setFeatureSelection('Ontwikkellocaties', 'plaatsnaam', plan_name)
            self.setExtentToSelection('Ontwikkellocaties', 10000.0)

    def zoomOutPlan(self):
        # unselect and zoom to extent of entire layer
        self.setFeatureSelection('Ontwikkellocaties')
        self.setExtentToLayer('Ontwikkellocaties')

    ###
    # Verbindingen
    def loadVerbindingenLayers(self):
        self.setLayerVisible('Treinstations (achtergrond)', True)
        # stations
        self.setStationAttribute()
        self.showStation(self.dlg.isStationVisible())
        # locations
        self.setLocationType()
        self.showLocation(self.dlg.isLocationVisible())

    # Station methods
    def showStation(self, onoff):
        self.setLayerVisible('Afvangstations', onoff)
        self.setLayerExpanded('Afvangstations', onoff)
        if self.dlg.isStationSelected():
            self.setLayerVisible('Invloedsgebied', onoff)
            self.setLayerExpanded('Invloedsgebied', onoff)

    def setStationAttribute(self):
        current_attribute = self.dlg.getSationAttribute().lower()
        #self.afvangstation = ''
        #self.station_ov_routes = ''
        # apply relevant style
        fields = ['halte_naam']
        new_fields = []
        headers = ['Station']
        new_headers = []
        style = ''
        if current_attribute in ('passanten', 'overstappers'):
            new_fields = [current_attribute,
                          'lopen_voortransport', 'lopen_natransport',
                          'fiets_voortransport', 'fiets_natransport',
                          'btm_voortransport', 'btm_natransport',
                          'pr_voortransport', 'pr_natransport']
            new_headers = ['Totaal',
                           'Lopen voor %', 'Lopen na %',
                           'Fiets voor %', 'Fiets na %',
                           'BTM voor %', 'BTM na %',
                           'P+R voor %', 'P+R na %']
            style = current_attribute
        elif current_attribute == 'in- en uitstappers trein':
            new_fields = ['in_uit_trein',
                          'lopen_voortransport', 'lopen_natransport',
                          'fiets_voortransport', 'fiets_natransport',
                          'btm_voortransport', 'btm_natransport',
                          'pr_voortransport', 'pr_natransport']
            new_headers = ['Totaal',
                           'Lopen voor %', 'Lopen na %',
                           'Fiets voor %', 'Fiets na %',
                           'BTM voor %', 'BTM na %',
                           'P+R voor %', 'P+R na %']
            style = 'in_uit_trein'
        elif current_attribute == 'in- en uitstappers btm':
            new_fields = ['in_uit_btm', 'btm_voortransport', 'btm_natransport']
            new_headers = ['Totaal', 'BTM voor %', 'BTM na %']
            style = 'in_uit_btm'
        elif current_attribute == 'fiets bezetting %':
            new_fields = ['fiets_plaatsen', 'fiets_bezetting', 'fiets_voortransport', 'fiets_natransport']
            new_headers = ['Plaatsen', 'Bezetting %', 'Fiets voor %', 'Fiets na %']
            style = 'fiets_bezetting'
        elif current_attribute == 'p+r bezetting %':
            new_fields = ['pr_plaatsen', 'pr_bezetting', 'pr_voortransport', 'pr_natransport']
            new_headers = ['Plaatsen', 'Bezetting %', 'P+R voor %', 'P+R na %']
            style = 'pr_bezetting'
        elif current_attribute == 'ov fiets':
            new_fields = ['ov_fietsen', 'lopen_voortransport', 'lopen_natransport', 'btm_voortransport', 'btm_natransport']
            new_headers = ['Totaal', 'Lopen voor %', 'Lopen na %', 'BTM voor %', 'BTM na %']
            style = 'ov_fietsen'
        self.setLayerStyle('Afvangstations', 'verbindingen_%s' % style)
        # whenever there's a change at this level, update the values table
        fields.extend(new_fields)
        headers.extend(new_headers)
        self.setCurrentLayer('Afvangstations')
        feature_values = self.getFeatureValues('Afvangstations', fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateStationsTable(headers, values)
        # reset locations
        # self.setLocationType()

    def zoomToStation(self, station_name):
        self.afvangstation = station_name
        # select station
        self.setFeatureSelection('Afvangstations', 'halte_naam', self.afvangstation)
        self.setCurrentLayer('Afvangstations')
        # filter BTM isochrones and show layer
        expression = '"halte_naam" = \'%s\'' % self.afvangstation
        self.setFilterExpression('Invloedsgebied', expression)
        self.setLayerVisible('Invloedsgebied', True)
        self.setLayerExpanded('Invloedsgebied', True)
        # identify station ov routes
        self.station_ov_routes = ''
        feature_values = self.getFeatureValues('Afvangstations', ['halte_naam', 'ov_routes'])
        for feat in feature_values.itervalues():
            if feat[0] == self.afvangstation:
                self.station_ov_routes = feat[1]
                break
        # filter OV routes
        if self.station_ov_routes:
            expression = '"route_id" IN (%s)' % ','.join(self.station_ov_routes.split(","))
        else:
            expression = ''
        self.filterOVRoutes(expression)
        self.showOVRoutes(True)
        # filter isochrone overlap
        self.setFilterExpression('Fiets invloedsgebied overlap', '')
        feature_values = self.getFeatureValues('Fiets invloedsgebied overlap', ['sid', 'station_namen'])
        overlap_ids = []
        for feat in feature_values.itervalues():
            station_names = feat[1].split(',')
            if self.afvangstation in station_names:
                overlap_ids.append(unicode(feat[0]))
        expression = 'sid IN (%s)' % ','.join(overlap_ids)
        self.setFilterExpression('Fiets invloedsgebied overlap', expression)
        self.updateLocationTable()
        # filter bike routes
        expression = '"station_naam" = \'%s\'' % self.afvangstation
        self.setFilterExpression('Fietsroutes', expression)
        self.showFietsRoutes(True)
        # zoom to isochrones layer
        self.setExtentToLayer('Invloedsgebied')
        if self.location:
            self.zoomToLocation(self.location)

    def zoomOutStation(self):
        # unselect station
        self.setFeatureSelection('Afvangstations')
        self.afvangstation = ''
        self.station_ov_routes = ''
        # hide OV routes
        self.filterOVRoutes('')
        self.showOVRoutes(False)
        # update fiets invloedsgebied overlap
        self.setFilterExpression('Fiets invloedsgebied overlap', '')
        self.updateLocationTable()
        # hide fiets routes
        self.setFilterExpression('Fietsroutes', '')
        self.showFietsRoutes(False)
        # hide isochrones layer
        self.setFilterExpression('Invloedsgebied', '')
        self.setLayerVisible('Invloedsgebied', False)
        self.setLayerExpanded('Invloedsgebied', False)
        if self.location:
            self.zoomToLocation(self.location)
        else:
            self.setExtentToLayer('Afvangstations')

    # Location methods
    def showLocation(self, onoff):
        location_type = self.dlg.getLocationType()
        location_layer = ''
        # hide all locations
        self.setLayerVisible('Fiets invloedsgebied overlap', False)
        self.setLayerExpanded('Fiets invloedsgebied overlap', False)
        self.setLayerVisible('Magneten', False)
        self.setLayerExpanded('Magneten', False)
        self.setLayerVisible('Belangrijke locaties', False)
        self.setLayerExpanded('Belangrijke locaties', False)
        # show only the selected location type
        if onoff:
            if location_type == 'Invloedsgebied overlap':
                location_layer = 'Fiets invloedsgebied overlap'
            elif location_type == 'Belangrijke locaties':
                location_layer = 'Belangrijke locaties'
            elif location_type == 'Magneten':
                location_layer = 'Magneten'
            # show location layer
            self.setLayerVisible(location_layer, True)
            self.setLayerExpanded(location_layer, True)

    def setLocationType(self):
        self.updateLocationTable()
        # make relevant layers visible
        if self.dlg.isLocationVisible():
            self.showLocation(True)
        # switch route layers
        self.zoomOutLocation()

    def updateLocationTable(self):
        location_type = self.dlg.getLocationType()
        location_layer = ''
        fields = []
        headers = []
        # prepare table
        if location_type == 'Invloedsgebied overlap':
            fields = ['sid', 'intensiteit', 'station_namen']
            headers = ['Id', 'Intensiteit', 'Treinstations']
            location_layer = 'Fiets invloedsgebied overlap'
        elif location_type == 'Belangrijke locaties':
            fields = ['sid', 'locatie_naam']
            headers = ['Id', 'Naam']
            location_layer = 'Belangrijke locaties'
        elif location_type == 'Magneten':
            fields = ['sid', 'locatie_naam']
            headers = ['Id', 'Naam']
            location_layer = 'Magneten'
        # get values
        feature_values = self.getFeatureValues(location_layer, fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateLocationsTable(headers, values)

    def zoomToLocation(self, location_id):
        self.location = location_id
        location_type = self.dlg.getLocationType()
        if location_type in ('Belangrijke locaties', 'Magneten'):
            self.setCurrentLayer(location_type)
            # select location
            route_ids = ''
            self.setFeatureSelection(location_type, 'sid', location_id)
            self.setExtentToSelection(location_type, 30000.0)
            # get route ids
            feature_values = self.getFeatureValues(location_type, ['sid', 'ov_routes_ids'])
            for feat in feature_values.itervalues():
                if feat[0] == int(location_id):
                    route_ids = feat[1]
                    break
            if route_ids:
                # filter BTM lines
                if self.station_ov_routes:
                    station_routes = self.station_ov_routes.split(",")
                    routes = []
                    for route in route_ids.split(","):
                        if route in station_routes:
                            routes.append(route)
                    expression = '"route_id" IN (%s)' % ','.join(routes)
                else:
                    expression = '"route_id" IN (%s)' % route_ids
                self.filterOVRoutes(expression)
                # show BTM lines layers
                self.showOVRoutes(True)
            else:
                self.filterOVRoutes('')
                self.showOVRoutes(False)
            self.showFietsRoutes(False)
        else:
            # select location
            self.setFeatureSelection('Fiets invloedsgebied overlap', 'sid', location_id)
            self.setCurrentLayer('Fiets invloedsgebied overlap')
            # zoom to relevant layer
            if self.dlg.isStationSelected():
                self.setExtentToLayer('Invloedsgebied')
            else:
                self.setExtentToSelection('Fiets invloedsgebied overlap', 30000.0)
            # get fiets route ids
            fiets_route_ids = []
            feature_values = self.getFeatureValues('Fietsroutes', ['sid', 'invloedsgebied_ids', 'station_naam'])
            for feat in feature_values.itervalues():
                if feat[1]:
                    if self.afvangstation:
                            if location_id in feat[1].split(",") and self.afvangstation == feat[2]:
                                fiets_route_ids.append(unicode(feat[0]))
                    else:
                        if location_id in feat[1].split(","):
                            fiets_route_ids.append(unicode(feat[0]))
            # filter fiets routes
            if fiets_route_ids:
                expression = 'sid IN (%s)' % ','.join(fiets_route_ids)
                self.setFilterExpression('Fietsroutes', expression)
                # show bike routes layer
                self.showFietsRoutes(True)
            else:
                self.setFilterExpression('Fietsroutes', '')
                self.showFietsRoutes(False)
            self.showOVRoutes(False)

    def zoomOutLocation(self):
        location_type = self.dlg.getLocationType()
        if location_type in ('Belangrijke locaties', 'Magneten'):
            layer = location_type
        else:
            layer = 'Fiets invloedsgebied overlap'
            self.updateLocationTable()
        # unselect location
        self.setFeatureSelection(layer)
        self.location = ''
        # adjust zoom
        if self.afvangstation:
            self.zoomToStation(self.afvangstation)
        else:
            # hide OV routes
            self.filterOVRoutes('')
            self.showOVRoutes(False)
            # hide fiets routes
            self.setFilterExpression('Fietsroutes', '')
            self.showFietsRoutes(False)
            # hide isochrones
            self.setFilterExpression('Invloedsgebied', '')
            self.setLayerVisible('Invloedsgebied', False)
            self.setLayerExpanded('Invloedsgebied', False)
            # zoom out
            self.setExtentToLayer(layer)

    def showFietsRoutes(self, onoff):
        self.setLayerVisible('Fietsroutes', onoff)
        self.setLayerExpanded('Fietsroutes', onoff)

    def showOVRoutes(self, onoff):
        # self.setLayerVisible('OV haltes', onoff)
        # self.setLayerExpanded('OV haltes', onoff)
        self.setLayerVisible('Buslijnen', onoff)
        self.setLayerExpanded('Buslijnen', onoff)
        self.setLayerVisible('Tramlijnen', onoff)
        self.setLayerExpanded('Tramlijnen', onoff)
        self.setLayerVisible('Metrolijnen', onoff)
        self.setLayerExpanded('Metrolijnen', onoff)

    def filterOVRoutes(self, expression):
        if expression:
            self.setFilterExpression('Buslijnen', '"modaliteit" = \'bus\' AND %s' % expression)
            self.setFilterExpression('Tramlijnen', '"modaliteit" = \'tram\' AND %s' % expression)
            self.setFilterExpression('Metrolijnen', '"modaliteit" = \'metro\' AND %s' % expression)
        else:
            self.setFilterExpression('Buslijnen', '"modaliteit" = \'bus\'')
            self.setFilterExpression('Tramlijnen', '"modaliteit" = \'tram\'')
            self.setFilterExpression('Metrolijnen', '"modaliteit" = \'metro\'')

    ###
    # Mobiliteit
    # Isochrone methods
    def loadMobiliteitLayers(self):
        self.setLayerVisible('Treinstations (achtergrond)', True)
        self.loadForegroundLayers(True)
        self.setLayerVisible('Treinstations (voorgrond)', True)
        # isochrones
        self.showWalkIsochrones(self.dlg.isWalkVisible())
        self.showBikeIsochrones(self.dlg.isBikeVisible())
        self.showOVIsochrones(self.dlg.isOvVisible())
        # PTAL
        self.showAccessibility(self.dlg.isPTALVisible())
        # frequency
        self.setStopFrequency()
        self.showStopFrequency(self.dlg.isStopsVisible())

    def showWalkIsochrones(self, onoff):
        self.setLayerVisible('Invloedsgebied lopen', onoff)
        if onoff:
            self.setCurrentLayer('Invloedsgebied lopen')

    def showBikeIsochrones(self, onoff):
        self.setLayerVisible('Invloedsgebied fiets', onoff)
        if onoff:
            self.setCurrentLayer('Invloedsgebied fiets')

    def showOVIsochrones(self, onoff):
        self.setLayerVisible('Invloedsgebied tram', onoff)
        self.setLayerVisible('Invloedsgebied metro', onoff)
        self.setLayerVisible('Invloedsgebied bus', onoff)
        if onoff:
            self.setCurrentLayer('Invloedsgebied bus')

    # PTAL methods
    def setAccessibility(self):
        if self.dlg.isPTALVisible():
            self.showAccessibility(True)

    def showAccessibility(self, onoff):
        selection = self.dlg.getPTAL()
        if onoff:
            self.setLayerVisible(selection, True)
            self.setCurrentLayer(selection)
            self.setLayerExpanded(selection, True)
            if selection == 'Bereikbaarheidsniveau':
                self.setLayerVisible('Bereikbaarheidsindex', False)
                self.setLayerExpanded('Bereikbaarheidsindex', False)
            else:
                self.setLayerVisible('Bereikbaarheidsniveau', False)
                self.setLayerExpanded('Bereikbaarheidsniveau', False)
        else:
            self.setLayerVisible('Bereikbaarheidsniveau', False)
            self.setLayerExpanded('Bereikbaarheidsniveau', False)
            self.setLayerVisible('Bereikbaarheidsindex', False)
            self.setLayerExpanded('Bereikbaarheidsindex', False)

    # Stop Frequency methods
    def setStopFrequency(self):
        time_period = self.dlg.getTimePeriod()
        self.setLayerStyle('Trein frequentie', 'mobiliteit_trein_%s' % time_period.lower())
        self.setLayerStyle('Metro frequentie', 'mobiliteit_metro_%s' % time_period.lower())
        self.setLayerStyle('Tram frequentie', 'mobiliteit_tram_%s' % time_period.lower())
        self.setLayerStyle('Bus frequentie', 'mobiliteit_bus_%s' % time_period.lower())
        self.updateStopSummaryTable()

    def setStopTypes(self):
        if self.dlg.isStopsVisible():
            self.showStopFrequency(True)
        else:
            self.hideStopFrequency()
        self.updateStopSummaryTable()

    def showStopFrequency(self, onoff):
        current_type = self.dlg.getStops()
        if current_type == 'Alle OV haltes':
            self.setLayerVisible('Treinstations (voorgrond)', False)
            self.setLayerVisible('Treinstations (achtergrond)', False)
            self.setLayerVisible('Trein frequentie', onoff)
            self.setLayerExpanded('Trein frequentie', onoff)
            self.setCurrentLayer('Trein frequentie')
            self.setLayerVisible('Metro frequentie', onoff)
            self.setLayerExpanded('Metro frequentie', onoff)
            self.setLayerVisible('Tram frequentie', onoff)
            self.setLayerExpanded('Tram frequentie', onoff)
            self.setLayerVisible('Bus frequentie', onoff)
            self.setLayerExpanded('Bus frequentie', onoff)
        else:
            self.hideStopFrequency()
            self.setLayerVisible('Treinstations (voorgrond)', False)
            self.setLayerVisible('Treinstations (achtergrond)', True)
            if current_type == 'Treinstations':
                self.setLayerVisible('Treinstations (achtergrond)', False)
                self.setLayerVisible('Trein frequentie', onoff)
                self.setLayerExpanded('Trein frequentie', onoff)
                self.setCurrentLayer('Trein frequentie')
            elif current_type == 'Metrostations':
                self.setLayerVisible('Metro frequentie', onoff)
                self.setLayerExpanded('Metro frequentie', onoff)
                self.setCurrentLayer('Metro frequentie')
            elif current_type == 'Tramhaltes':
                self.setLayerVisible('Tram frequentie', onoff)
                self.setLayerExpanded('Tram frequentie', onoff)
                self.setCurrentLayer('Tram frequentie')
            elif current_type == 'Bushaltes':
                self.setLayerVisible('Bus frequentie', onoff)
                self.setLayerExpanded('Bus frequentie', onoff)
                self.setCurrentLayer('Bus frequentie')

    def hideStopFrequency(self):
        self.setLayerVisible('Trein frequentie', False)
        self.setLayerExpanded('Trein frequentie', False)
        self.setLayerVisible('Metro frequentie', False)
        self.setLayerExpanded('Metro frequentie', False)
        self.setLayerVisible('Tram frequentie', False)
        self.setLayerExpanded('Tram frequentie', False)
        self.setLayerVisible('Bus frequentie', False)
        self.setLayerExpanded('Bus frequentie', False)

    def updateStopSummaryTable(self):
        time_period = self.dlg.getTimePeriod().lower()
        current_type = self.dlg.getStops()
        stops_layer = ''
        # prepare table
        if current_type == 'Treinstations':
            fields = ['halte_naam',
                      'trein_%s' % time_period,
                      'hsl_%s' % time_period,
                      'ic_%s' % time_period,
                      'spr_%s' % time_period]
            headers = ['Treinstation', 'Totaal', 'HSL', 'IC', 'Sprinter']
            stops_layer = 'Trein frequentie'
        elif current_type == 'Metrostations':
            fields = ['halte_naam', 'metro_%s' % time_period]
            headers = ['Metrostation', 'Totaal']
            stops_layer = 'Metro frequentie'
        elif current_type == 'Tramhaltes':
            fields = ['halte_naam', 'tram_%s' % time_period]
            headers = ['Tramhalte', 'Totaal']
            stops_layer = 'Tram frequentie'
        elif current_type == 'Bushaltes':
            fields = ['halte_naam', 'halte_gemeente', 'bus_%s' % time_period]
            headers = ['Bushalte', 'Gemeente', 'Totaal']
            stops_layer = 'Bus frequentie'
        else:
            fields = ['halte_naam',
                      'trein_%s' % time_period,
                      'metro_%s' % time_period,
                      'tram_%s' % time_period,
                      'bus_%s' % time_period]
            headers = ['OV Halte', 'Trein', 'Metro', 'Tram', 'Bus']
        # get values
        if current_type == 'Alle OV haltes':
            feature_values = self.getFeatureValues('Trein frequentie', fields)
            more_values = self.getFeatureValues('Metro frequentie', fields)
            feature_values.update(more_values)
            more_values = self.getFeatureValues('Tram frequentie', fields)
            feature_values.update(more_values)
            more_values = self.getFeatureValues('Bus frequentie', fields)
            feature_values.update(more_values)
            #self.setExtentToLayer('Bus frequentie')
        else:
            feature_values = self.getFeatureValues(stops_layer, fields)
            #self.setExtentToLayer(stops_layer)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateStopsTable(headers, values)

    def zoomToStop(self, stop_name):
        self.deselectStops()
        current_type = self.dlg.getStops()
        self.selected_stop = stop_name
        if current_type == 'Treinstations':
            # select stop
            self.setFeatureSelection('Trein frequentie', 'halte_naam', stop_name)
            # zoom to stop
            self.setExtentToSelection('Trein frequentie', 15000.0)
            self.setCurrentLayer('Trein frequentie')
        elif current_type == 'Metrostations':
            self.setFeatureSelection('Metro frequentie', 'halte_naam', stop_name)
            self.setExtentToSelection('Metro frequentie', 15000.0)
            self.setCurrentLayer('Metro frequentie')
        elif current_type == 'Tramhaltes':
            self.setFeatureSelection('Tram frequentie', 'halte_naam', stop_name)
            self.setExtentToSelection('Tram frequentie', 15000.0)
            self.setCurrentLayer('Tram frequentie')
        elif current_type == 'Bushaltes':
            self.setFeatureSelection('Bus frequentie', 'halte_naam', stop_name)
            self.setExtentToSelection('Bus frequentie', 15000.0)
            self.setCurrentLayer('Bus frequentie')
        else:
            # here must find first instance of stop
            is_found = self.setFeatureSelection('Bus frequentie', 'halte_naam', stop_name)
            if not is_found:
                is_found = self.setFeatureSelection('Tram frequentie', 'halte_naam', stop_name)
            else:
                self.setExtentToSelection('Bus frequentie', 15000.0)
                self.setCurrentLayer('Bus frequentie')
            if not is_found:
                is_found = self.setFeatureSelection('Metro frequentie', 'halte_naam', stop_name)
            else:
                self.setExtentToSelection('Tram frequentie', 15000.0)
                self.setCurrentLayer('Tram frequentie')
            if not is_found:
                is_found = self.setFeatureSelection('Trein frequentie', 'halte_naam', stop_name)
                if is_found:
                    self.setExtentToSelection('Trein frequentie', 15000.0)
                    self.setCurrentLayer('Trein frequentie')
            else:
                self.setExtentToSelection('Metro frequentie', 15000.0)
                self.setCurrentLayer('Metro frequentie')

    def deselectStops(self):
        self.setFeatureSelection('Bus frequentie')
        self.setFeatureSelection('Tram frequentie')
        self.setFeatureSelection('Metro frequentie')
        self.setFeatureSelection('Trein frequentie')

    def zoomOutStop(self):
        self.selected_stop = ''
        self.deselectStops()
        current_type = self.dlg.getStops()
        if current_type == 'Treinstations':
            self.setExtentToLayer('Trein frequentie')
        elif current_type == 'Metrostations':
            self.setExtentToLayer('Metro frequentie')
        elif current_type == 'Tramhaltes':
            self.setExtentToLayer('Tram frequentie')
        else:
            self.setExtentToLayer('Bus frequentie')

    ####
    # General methods used by all panels
    ####
    def setCurrentLayer(self, layer_name):
        self.legend.setCurrentLayer(self.data_layers[layer_name])

    def setLayerVisible(self, layer_name, onoff):
        self.legend.setLayerVisible(self.data_layers[layer_name], onoff)

    def setLayerExpanded(self, layer_name, onoff):
        self.legend.setLayerExpanded(self.data_layers[layer_name], onoff)

    def setFilterExpression(self, layer_name, expression):
        try:
            success = self.data_layers[layer_name].setSubsetString(expression)
        except:
            success = False
        return success

    def setLayerStyle(self, layer_name, style_name):
        layer = self.data_layers[layer_name]
        layer.loadNamedStyle("%s/data/styles/%s.qml" % (self.plugin_dir, style_name))
        layer.triggerRepaint()
        self.legend.refreshLayerSymbology(layer)
        self.canvas.refresh()

    def getFeatureValues(self, layer_name, fields):
        values = {}
        layer = self.data_layers[layer_name]
        features = layer.getFeatures()
        if fields:
            for feat in features:
                values[feat.id()] = [feat.attribute(name) for name in fields]
        else:
            for feat in features:
                values[feat.id()] = feat.attributes()
        return values

    def setFeatureSelection(self, layer_name, field='', selected=''):
        layer = self.data_layers[layer_name]
        selection = []
        if field and selected:
            features = layer.getFeatures()
            for feat in features:
                if unicode(feat.attribute(field)) == unicode(selected):
                    selection.append(feat.id())
        if selection:
            layer.setSelectedFeatures(selection)
            return True
        else:
            layer.removeSelection()
            return False

    def setExtentToLayer(self, layer_name):
        layer = self.data_layers[layer_name]
        self.canvas.setExtent(layer.extent())
        self.canvas.refresh()

    def setExtentToSelection(self, layer_name, zoom_level=None):
        layer = self.data_layers[layer_name]
        if layer.selectedFeatures():
            self.canvas.zoomToSelected(layer)
            if zoom_level:
                self.canvas.zoomScale(zoom_level)
            self.canvas.refresh()
