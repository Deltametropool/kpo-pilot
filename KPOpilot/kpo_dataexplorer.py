# -*- coding: utf-8 -*-
"""
/***************************************************************************
 KPOpilotDockWidget
                                 A QGIS plugin
 Knooppunten Datasysteem
                             -------------------
        begin                : 2016-12-19
        git sha              : $Format:%H$
        copyright            : (C) 2016 by Jorge Gil
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

# from PyQt4.QtCore import QFileInfo, QTimer, SIGNAL


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
        # koppelingen
        self.dlg.stationAttributeChanged.connect(self.setStationAttribute)
        self.dlg.stationShow.connect(self.showStation)
        self.dlg.stationSelected.connect(self.zoomToStation)
        self.dlg.locationTypeChanged.connect(self.setLocationType)
        self.dlg.locationShow.connect(self.showLocation)
        self.dlg.locationSelected.connect(self.zoomToLocation)
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
            'inwoners': ['Maximum: 25 inwoners',
                         'Maximum: 50 inwoners',
                         'Maximum: 100 inwoners',
                         'Maximum: 150 inwoners',
                         'Maximum: 200 inwoners',
                         'Maximum: 250 inwoners',
                         'Maximum: 250 of meer inwoners'],
            'huishoudens': ['Maximum: 10 huishoudens',
                            'Maximum: 20 huishoudens',
                            'Maximum: 40 huishoudens',
                            'Maximum: 60 huishoudens',
                            'Maximum: 80 huishoudens',
                            'Maximum: 100 huishoudens',
                            'Maximum: 100 of meer huishoudens'],
            'intensiteit': ['Maximum: 10 werknemers/studenten',
                            'Maximum: 25 werknemers/studenten',
                            'Maximum: 50 werknemers/studenten',
                            'Maximum: 100 werknemers/studenten',
                            'Maximum: 200 werknemers/studenten',
                            'Maximum: 300 werknemers/studenten',
                            'Maximum: 300 of meer werknemers/studenten'],
            'fysieke_dichtheid': ['Maximum: 0.1 FSI',
                                  'Maximum: 0.4 FSI',
                                  'Maximum: 0.7 FSI',
                                  'Maximum: 1.0 FSI',
                                  'Maximum: 1.5 FSI',
                                  'Maximum: 2.0 FSI',
                                  'Maximum: 2.0 of meer FSI'],
            'woz_waarde': ['Maximum: 150k WOZ',
                           'Maximum: 200k WOZ',
                           'Maximum: 300k WOZ',
                           'Maximum: 500k WOZ',
                           'Maximum: 750k WOZ',
                           'Maximum: 1000k WOZ',
                           'Maximum: 1000k of meer WOZ']
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
            'inwoners': [25, 50, 100, 150, 200, 250],
            'huishoudens': [10, 20, 40, 60, 80, 100],
            'intensiteit': [10, 25, 50, 100, 200, 300],
            'fysieke_dichtheid': [0.1, 0.4, 0.7, 1.0, 1.5, 2.0],
            'woz_waarde': [150, 200, 300, 500, 750, 1000]
        }
        # globals
        self.intensity_level = '"inwoners" < 250'
        self.ptal_level = '"ov_bereikbaarheidsniveau" in (\'1a\', \'1b\', \'2\', \'3\', \'4\', \'5\', \'6a\', \'6b\')'

    ###
    # General
    def onShow(self, onoff):
        if onoff is True:
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
            # show intro tab
            self.dlg.resetQuestionTab()

    def loadTabLayers(self, tab_id):
        # hide all groups
        for i in range(0, 5):
            self.legend.setGroupVisible(i, False)
            self.legend.setGroupExpanded(i, False)
        # self.setLayerVisible('Treinstations', True)
        # show only selected group
        if tab_id == 1:
            self.loadKnooppuntenLayers()
            self.legend.setGroupExpanded(1, True)
        elif tab_id == 2:
            self.loadVerstedelijkingLayers()
            self.legend.setGroupExpanded(2, True)
        elif tab_id == 3:
            self.loadVerbindingenLayers()
            self.legend.setGroupExpanded(3, True)
        elif tab_id == 4:
            self.loadMobiliteitLayers()
            self.legend.setGroupExpanded(4, True)

    def loadForegroundLayers(self, onoff):
        self.legend.setGroupVisible(0, onoff)

    ###
    # Knooppunten
    def loadKnooppuntenLayers(self):
        self.loadForegroundLayers(True)
        # scenario layers
        self.setScenarioLayers()
        self.showScenario(self.dlg.isScenarioVisible())
        # isochrone layers
        self.showIsochrones(self.dlg.isIsochronesVisible())
        # knooppunten layers
        self.setKnooppuntenAttribute()
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
            self.setFilterExpression('Knooppuntenscenarios', expression)
        # update scenario summary
        self.setFilterExpression('Overzicht_woonscenarios', expression)
        summary_values = []
        fields = ('verwachte_huishoudens', 'op_loopafstand', 'op_fietsafstand', 'buiten_invloedsgebied')
        feature_values = self.getFeatureValues('Overzicht_woonscenarios', fields)
        # get first result, should be only one
        for values in feature_values.itervalues():
            summary_values = values
            break
        self.dlg.updateScenarioSummary(summary_values)
        # update knooppunten
        self.setKnooppuntenAttribute()
        if self.dlg.isKnooppuntVisible():
            self.showKnooppunten(True)

    def showIsochrones(self, onoff):
        self.setFilterExpression('Loopafstand (800 m)', '"modaliteit"=\'walk\'')
        self.setLayerVisible('Loopafstand (800 m)', onoff)
        self.setFilterExpression('Fietsafstand (3000 m)', '"modaliteit"=\'fiets\'')
        self.setLayerVisible('Fietsafstand (3000 m)', onoff)

    # Knooppunten methods
    def showKnooppunten(self, onoff):
        current_scenario = self.dlg.getScenario()
        if onoff:
            self.setLayerVisible('Treinstations (voorgrond)', False)
            if current_scenario == 'Huidige situatie':
                self.setLayerVisible('Knooppunten', True)
                self.setLayerExpanded('Knooppunten', True)
                self.setLayerVisible('Knooppuntenscenarios', False)
                self.setLayerExpanded('Knooppuntenscenarios', False)
                self.setCurrentLayer('Knooppunten')
            else:
                self.setLayerVisible('Knooppunten', False)
                self.setLayerExpanded('Knooppunten', False)
                self.setLayerVisible('Knooppuntenscenarios', True)
                self.setLayerExpanded('Knooppuntenscenarios', True)
                self.setCurrentLayer('Knooppuntenscenarios')
        else:
            self.setLayerVisible('Treinstations (voorgrond)', True)
            self.setLayerVisible('Knooppunten', False)
            self.setLayerExpanded('Knooppunten', False)
            self.setLayerVisible('Knooppuntenscenarios', False)
            self.setLayerExpanded('Knooppuntenscenarios', False)
            self.setCurrentLayer('Woonscenarios')

    def setKnooppuntenAttribute(self):
        # identify scenario layer to use
        current_scenario = self.dlg.getScenario()
        current_attribute = self.dlg.getKnooppuntKenmerk()
        if current_scenario == 'Huidige situatie':
            knoopunt_layer = 'Knooppunten'
        else:
            knoopunt_layer = 'Knooppuntenscenarios'
        # apply relevant style
        field = ''
        header = 'Totaal'
        if current_attribute.lower() in ('passanten', 'bezoekers', 'overstappers'):
            self.setLayerStyle(knoopunt_layer, '%s_%s' % (knoopunt_layer.lower(), current_attribute.lower()))
            if current_attribute == 'Passanten':
                field = 'totaal_passanten'
            else:
                field = current_attribute.lower()
        elif current_attribute == 'In- en uitstappers trein':
            field = 'in_uit_trein'
            self.setLayerStyle(knoopunt_layer, '%s_%s' % (knoopunt_layer.lower(), field))
        elif current_attribute == 'In- en uitstappers BTM':
            field = 'in_uit_btm'
            self.setLayerStyle(knoopunt_layer, '%s_%s' % (knoopunt_layer.lower(), field))
        elif current_attribute == 'Fiets bezetting %':
            field = 'fiets_bezetting'
            self.setLayerStyle(knoopunt_layer, '%s_%s' % (knoopunt_layer.lower(), field))
            header = 'Bezetting %'
        elif current_attribute == 'P+R bezetting %':
            field = 'pr_bezetting'
            header = 'Bezetting %'
            self.setLayerStyle(knoopunt_layer, '%s_%s' % (knoopunt_layer.lower(), field))
        # whenever there's a change at this level, update the values table
        if current_scenario == 'Huidige situatie':
            fields = ['halte_naam', field]
            headers = ['Station', header]
            self.setCurrentLayer('Knooppunten')
        else:
            fields = ['halte_naam', field, 'procentuele_verandering']
            headers = ['Station', header, '% Verandering']
            self.setCurrentLayer('Knooppuntenscenarios')
        feature_values = self.getFeatureValues(knoopunt_layer, fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateKnooppuntenTable(headers, values)

    def zoomToKnooppunt(self, node_name):
        expression = ' AND "halte_naam"=\'%s\'' % node_name
        # show isochrones for that station only
        self.setFilterExpression('Loopafstand (800 m)', '"modaliteit"=\'walk\'%s' % expression)
        self.setFilterExpression('Fietsafstand (3000 m)', '"modaliteit"=\'fiets\'%s' % expression)
        # zoom to fiets isochrone extent
        self.setExtentToLayer('Fietsafstand (3000 m)')

    ###
    # Verstedelijking
    def loadVerstedelijkingLayers(self):
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
        self.setLayerVisible('Onderbenut bereikbare lokaties', False)
        if onoff:
            if not self.dlg.isIntensityVisible() and not self.dlg.isAccessibilityVisible():
                self.setLayerVisible('Onderbenut bereikbare lokaties', onoff)
                self.setCurrentLayer('Onderbenut bereikbare lokaties')

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
        if intensity_type == 'Inwoners':
            label = self.onderbenutLabels['inwoners'][intensity_level]
            if intensity_level < 6:
                expression = '"inwoners" < %s' % self.onderbenutLevels['inwoners'][intensity_level]
            style = 'verstedelijking_inwoners'
        elif intensity_type == 'Huishouden':
            label = self.onderbenutLabels['huishoudens'][intensity_level]
            if intensity_level < 6:
                expression = '"huishoudens" < %s' % self.onderbenutLevels['huishoudens'][intensity_level]
            style = 'verstedelijking_huishoudens'
        elif intensity_type == 'Intensiteit (werknemer, studenten)':
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
                expression = '"woz_waarde" < %s' % self.onderbenutLevels['woz_waarde'][intensity_level]
            style = 'verstedelijking_woz'
        # update dialog label
        self.dlg.updateIntensityLabel(label)
        # update layers
        self.setFilterExpression('Ruimtelijke kenmerken', expression)
        self.setLayerStyle('Ruimtelijke kenmerken', style)
        self.intensity_level = expression
        self.identifySpatialPotential()

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
        expression  = ''
        if self.ptal_level and self.intensity_level:
            expression = '%s AND %s' % (self.ptal_level, self.intensity_level)
        elif self.ptal_level:
            expression = self.ptal_level
        elif self.intensity_level:
            expression = self.intensity_level
        self.setFilterExpression('Onderbenut bereikbare lokaties', expression)
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
        headers = ''
        fields = ''
        if plan_type == 'RAP 2020':
            expression = '"plan_naam" = \'%s\'' % plan_type
            style = 'verstedelijking_RAP'
            fields = ['gemeente', 'geplande_woningen']
            headers = ['Gemeente', 'Woningen']
        elif plan_type == 'RAP minder Plancapaciteit':
            expression = '"plan_naam" = \'%s\'' % plan_type
            style = 'verstedelijking_RAP'
            fields = ['gemeente', 'geplande_woningen', 'net_nieuwe_woningen']
            headers = ['Gemeente', 'Woningen', 'Verschil']
        elif plan_type in ('Plancapaciteit', 'Leegstanden'):
            expression = '"plan_naam" = \'%s\' AND "plaatsnaam" IS NOT NULL' % plan_type
            style = 'verstedelijking_plancapaciteit'
            fields = ['plaatsnaam', 'geplande_woningen', 'gemiddelde_bereikbaarheidsindex']
            headers = ['Plaatsnaam', 'Woningen', 'PTAL']
        self.setFilterExpression('Ontwikkellocaties', expression)
        self.setLayerStyle('Ontwikkellocaties', style)
        self.setExtentToLayer('Ontwikkellocaties')
        # update table
        self.setCurrentLayer('Ontwikkellocaties')
        feature_values = self.getFeatureValues('Ontwikkellocaties', fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updatePlanTable(headers, values)
        #
        self.calculateIntersections()

    def calculateIntersections(self):
        # get all relevant cell attributes
        cell_ids = []
        gemeente = []
        cell_attributes = self.getFeatureValues('Onderbenut bereikbare lokaties', ['cell_id','gemeente'])
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
        if plan_type in ('RAP 2020', 'RAP minder Plancapaciteit'):
            # set plans that have gemeente in list to true
            for feature in base_features:
                if feature.attribute('gemeente') in gemeente:
                    houses_in += feature.attribute('geplande_woningen')
                else:
                    houses_out += feature.attribute('geplande_woningen')
        elif plan_type in ('Plancapaciteit', 'Leegstanden'):
            # set plans that have cell id in list to true
            for feature in base_features:
                ids = feature.attribute('cell_ids')
                if ids:
                    ids = ids.split(",")
                    if any(i in cell_ids for i in ids):
                        houses_in += feature.attribute('geplande_woningen')
                    else:
                        houses_out += feature.attribute('geplande_woningen')
                else:
                    houses_out += feature.attribute('geplande_woningen')
        # update summary
        total_houses = houses_in + houses_out
        self.dlg.updatePlanSummary([total_houses, houses_in, houses_out])

    def zoomToPlan(self, plan_name):
        plan_type = self.dlg.getPlanType()
        if plan_type in ('RAP 2020', 'RAP minder Plancapaciteit'):
            self.setFeatureSelection('Ontwikkellocaties', 'gemeente', plan_name)
            self.setExtentToSelection('Ontwikkellocaties')
        elif plan_type in ('Plancapaciteit', 'Leegstanden'):
            self.setFeatureSelection('Ontwikkellocaties', 'plaatsnaam', plan_name)
            self.setExtentToSelection('Ontwikkellocaties', 10000.0)

    ###
    # Verbindingen
    def loadVerbindingenLayers(self):
        # stations
        self.setStationAttribute()
        self.showStation(self.dlg.isStationVisible())
        # locations
        self.setLocationType()
        self.showLocation(self.dlg.isLocationVisible())

    # Station methods
    def showStation(self, onoff):
        self.setLayerVisible('Overbelast stations', onoff)
        self.setLayerExpanded('Overbelast stations', onoff)
        if onoff:
            self.setCurrentLayer('Overbelast stations')
            self.setExtentToLayer('Overbelast stations')
            # self.setLayerVisible('Treinstations', False)
        else:
            self.setLayerVisible('Isochronen BTM', False)
            # self.setLayerVisible('Treinstations', True)

    def setStationAttribute(self):
        current_attribute = self.dlg.getSationAttribute().lower()
        # apply relevant style
        field = ''
        header = 'Totaal'
        if current_attribute in ('passanten', 'bezoekers', 'overstappers'):
            self.setLayerStyle('Overbelast stations', 'verbindingen_%s' % current_attribute)
            if current_attribute == 'passanten':
                field = 'totaal_passanten'
            else:
                field = current_attribute
        elif current_attribute == 'in- en uitstappers trein':
            field = 'in_uit_trein'
            self.setLayerStyle('Overbelast stations', 'verbindingen_%s' % field)
        elif current_attribute == 'in- en uitstappers btm':
            field = 'in_uit_btm'
            self.setLayerStyle('Overbelast stations', 'verbindingen_%s' % field)
        elif current_attribute == 'fiets bezetting %':
            field = 'fiets_bezetting'
            self.setLayerStyle('Overbelast stations', 'verbindingen_%s' % field)
            header = 'Bezetting %'
        elif current_attribute == 'p+r bezetting %':
            field = 'pr_bezetting'
            header = 'Bezetting %'
            self.setLayerStyle('Overbelast stations', 'verbindingen_%s' % field)
        # whenever there's a change at this level, update the values table
        fields = ['halte_naam', field]
        headers = ['Station', header]
        self.setCurrentLayer('Overbelast stations')
        feature_values = self.getFeatureValues('Overbelast stations', fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateStationsTable(headers, values)
        # remove station filters
        self.setFilterExpression('Isochronen BTM', '')
        self.setFilterExpression('Invloedsgebied overlap', '')
        self.setFilterExpression('Fietsroutes', '')
        # hide isochrones layer
        self.setLayerVisible('Isochronen BTM', False)
        # reset locations
        self.setLocationType()

    def zoomToStation(self, station_name):
        # select station
        self.setFeatureSelection('Overbelast stations', 'halte_naam', station_name)
        # filter BTM isochrones and show layer
        expression = '"modaliteit" != \'fiets\' AND "halte_naam" = \'%s\'' % station_name
        self.setFilterExpression('Isochronen BTM', expression)
        self.setLayerVisible('Isochronen BTM', True)
        # filter isochrone overlap
        self.setFilterExpression('Invloedsgebied overlap', '')
        feature_values = self.getFeatureValues('Invloedsgebied overlap', ['sid', 'station_namen'])
        overlap_ids = []
        for feat in feature_values.itervalues():
            station_names = feat[1].split(',')
            if station_name in station_names:
                overlap_ids.append(str(feat[0]))
        expression = 'sid IN (%s)' % ','.join(overlap_ids)
        self.setFilterExpression('Invloedsgebied overlap', expression)
        self.setLocationType()
        # filter bike routes
        expression = '"station_naam" = \'%s\'' % station_name
        self.setFilterExpression('Fietsroutes', expression)
        # zoom to isochrones layer
        self.setExtentToLayer('Isochronen BTM')

    # Location methods
    def showLocation(self, onoff):
        location_type = self.dlg.getLocationType()
        location_layer = ''
        self.hideLocation()
        if onoff:
            # show selected location type
            if location_type in ('Overlap herkomst', 'Overlap bestemming'):
                location_layer = 'Invloedsgebied overlap'
            elif location_type == 'Belangrijke locaties':
                location_layer = 'Belangrijke locaties'
            elif location_type == 'Regionale voorzieningen':
                location_layer = 'Regionale voorzieningen'
            # show location layer
            self.setLayerVisible(location_layer, True)
            self.setLayerExpanded(location_layer, True)
            self.setCurrentLayer(location_layer)

    def hideLocation(self):
        # hide all locations and related layers
        self.setLayerVisible('Invloedsgebied overlap', False)
        self.setLayerExpanded('Invloedsgebied overlap', False)
        self.setLayerVisible('Regionale voorzieningen', False)
        self.setLayerExpanded('Regionale voorzieningen', False)
        self.setLayerVisible('Belangrijke locaties', False)
        self.setLayerExpanded('Belangrijke locaties', False)
        self.setLayerVisible('Fietsroutes', False)
        self.setLayerExpanded('Fietsroutes', False)
        self.setLayerVisible('Buslijnen', False)
        self.setLayerExpanded('Buslijnen', False)
        self.setLayerVisible('Tramlijnen', False)
        self.setLayerExpanded('Tramlijnen', False)
        self.setLayerVisible('Metrolijnen', False)
        self.setLayerExpanded('Metrolijnen', False)

    def setLocationType(self):
        location_type = self.dlg.getLocationType()
        location_layer = ''
        fields = []
        headers = []
        # prepare table
        if location_type == 'Overlap herkomst':
            fields = ['sid', 'inwoner_dichtheid', 'station_aantal']
            headers = ['Id', 'Inwoners', 'Aantal stations']
            location_layer = 'Invloedsgebied overlap'
        elif location_type == 'Overlap bestemming':
            fields = ['sid', 'intensiteit', 'station_aantal']
            headers = ['Id', 'Intensiteit', 'Aantal stations']
            location_layer = 'Invloedsgebied overlap'
        elif location_type == 'Belangrijke locaties':
            fields = ['sid', 'locatie_naam']
            headers = ['Id', 'Naam']
            location_layer = 'Belangrijke locaties'
        elif location_type == 'Regionale voorzieningen':
            fields = ['sid', 'type_locatie', 'locatie_naam']
            headers = ['Id', 'Type locatie', 'Naam']
            location_layer = 'Regionale voorzieningen'
        # get values
        feature_values = self.getFeatureValues(location_layer, fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateLocationsTable(headers, values)
        if self.dlg.isLocationVisible():
            self.showLocation(True)

    def zoomToLocation(self, location_id):
        location_type = self.dlg.getLocationType()
        if location_type in ('Overlap bestemming', 'Belangrijke locaties', 'Regionale voorzieningen'):
            # select location
            route_ids = ''
            if location_type == 'Overlap bestemming':
                layer_name = 'Invloedsgebied overlap'
            else:
                layer_name = location_type
            self.setFeatureSelection(layer_name, 'sid', int(location_id))
            if location_type == 'Overlap bestemming' and self.dlg.isStationSelected():
                self.setExtentToLayer('Isochronen BTM')
            else:
                self.setExtentToSelection(layer_name, 60000.0)
            # get route ids
            feature_values = self.getFeatureValues(layer_name, ['sid', 'ov_routes_ids'])
            for feat in feature_values.itervalues():
                if feat[0] == int(location_id):
                    route_ids = feat[1]
            if route_ids:
                # filter BTM lines
                expression = '"route_id" IN (%s)' % route_ids
                print expression
                self.setFilterExpression('Buslijnen', '"modaliteit" = \'bus\' AND %s' % expression)
                self.setFilterExpression('Tramlijnen', '"modaliteit" = \'tram\' AND %s' % expression)
                self.setFilterExpression('Metrolijnen', '"modaliteit" = \'metro\' AND %s' % expression)
                # show BTM lines layers
                # self.setLayerVisible('OV haltes', True)
                # self.setLayerExpanded('OV haltes', True)
                self.setLayerVisible('Buslijnen', True)
                self.setLayerExpanded('Buslijnen', True)
                self.setLayerVisible('Tramlijnen', True)
                self.setLayerExpanded('Tramlijnen', True)
                self.setLayerVisible('Metrolijnen', True)
                self.setLayerExpanded('Metrolijnen', True)
        else:
            # select location
            self.setFeatureSelection('Invloedsgebied overlap', 'sid', int(location_id))
            # zoom to relevant layer
            if self.dlg.isStationSelected():
                self.setExtentToLayer('Isochronen BTM')
            else:
                self.setExtentToSelection('Invloedsgebied overlap', 60000.0)
            # show bike routes layer
            self.setLayerVisible('Fietsroutes', True)
            self.setLayerExpanded('Fietsroutes', True)

    ###
    # Mobiliteit
    # Isochrone methods
    def loadMobiliteitLayers(self):
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
        self.setLayerVisible('Isochronen lopen', onoff)
        if onoff:
            self.setCurrentLayer('Isochronen lopen')

    def showBikeIsochrones(self, onoff):
        self.setLayerVisible('Isochronen fiets', onoff)
        if onoff:
            self.setCurrentLayer('Isochronen fiets')

    def showOVIsochrones(self, onoff):
        self.setLayerVisible('Isochronen tram', onoff)
        self.setLayerVisible('Isochronen metro', onoff)
        self.setLayerVisible('Isochronen bus', onoff)
        if onoff:
            self.setCurrentLayer('Isochronen bus')

    # PTAL methods
    def setAccessibility(self):
        if self.dlg.isPTALVisible():
            self.showPTAL(True)

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
            if current_type == 'Treinstations':
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
        else:
            feature_values = self.getFeatureValues(stops_layer, fields)
        values = []
        for feat in feature_values.itervalues():
            values.append(feat)
        self.dlg.updateStopsTable(headers, values)

    def zoomToStop(self, stop_name):
        current_type = self.dlg.getStops()
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

    def setFeatureSelection(self, layer_name, field, selected):
        layer = self.data_layers[layer_name]
        selection = []
        if selected:
            features = layer.getFeatures()
            for feat in features:
                if feat.attribute(field) == selected:
                    selection.append(feat.id())
        if selection:
            layer.setSelectedFeatures(selection)
            return True
        else:
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
