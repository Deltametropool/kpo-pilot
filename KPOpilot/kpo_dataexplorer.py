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

        # koppelingen

        # mobiliteit



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
            # populate the dictionary with all the payers for use throughout
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
        # show only selected group
        if tab_id == 1:
            self.loadKnooppuntenLayers()
            self.legend.setGroupExpanded(1, True)
        elif tab_id == 2:
            self.loadVerstedelijkingLayers()
            self.legend.setGroupExpanded(2, True)
        elif tab_id == 3:
            self.loadKnoppelingenLayers()
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
        if self.dlg.isScenarioVisible():
            self.showScenario(True)
        else:
            self.showScenario(False)
        # isochrone layers
        if self.dlg.isIsochronesVisible():
            self.showIsochrones(True)
        else:
            self.showIsochrones(False)
        # knooppunten layers
        self.setKnooppuntenAttribute()
        if self.dlg.isKnooppuntVisible():
            self.showKnooppunten(True)

    def showScenario(self, onoff):
        self.setLayerVisible('Woonscenarios', onoff)
        self.setLayerVisible('Buiten invloedsgebied', onoff)
        # expand layer to show legend icons
        self.setLayerExpanded('Woonscenarios', onoff)
        self.setCurrentLayer('Woonscenarios')
        self.loadForegroundLayers(onoff)

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
        # if self.dlg.isKnooppuntVisible():
        #    self.showKnooppunten(True)

    def showIsochrones(self, onoff):
        self.setFilterExpression('Loopafstand (800 m)', '"modaliteit"=\'walk\'')
        self.setLayerVisible('Loopafstand (800 m)', onoff)
        self.setFilterExpression('Fietsafstand (3000 m)', '"modaliteit"=\'fiets\'')
        self.setLayerVisible('Fietsafstand (3000 m)', onoff)

    def showKnooppunten(self, onoff):
        current_scenario = self.dlg.getScenario()
        if onoff:
            self.setLayerVisible('Stations (voorgrond)', False)
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
            self.setLayerVisible('Stations (voorgrond)', True)
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
            fields = ['station_naam', field]
            headers = ['Station', header]
            self.setCurrentLayer('Knooppunten')
        else:
            fields = ['station_naam', field, 'procentuele_verandering']
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
        pass

    def showIntensity(self):
        intensity = self.dlg.getIntensity()
        if self.dlg.intensityShowCheck.isChecked():
            self.setLayerVisible('Intensity', True)

        else:
            self.setLayerVisible('Intensity', False)
            # vl.setSubsetString( 'Counties = "Norwich"' )

    def setIntensityValueSlider(self):
        self.dlg.setSliderRange('intensityValueSlider', 0, 100, 10)
        self.dlg.updateIntensityValue()


    def setAccessibilityValueSlider(self):
        self.dlg.setSliderRange('accessibilityValueSlider', 0, 8, 1)
        self.dlg.updateAccessibilityValue()


    def showDevelopments(self):
        if self.dlg.locationShowCheck.isChecked():
            self.setLayerVisible('Development_locations', True)
        else:
            self.setLayerVisible('Development_locations', False)

    def updateDevelopmentSummaryText(self):
        development = self.dlg.getDevelopment()
        data = self.getLayerByName('Development_locations_summary')
        if data.isValid():
            for fet in data.getFeatures():
                if fet['locations_set'] == development.lower():
                    total = fet['new_households']
                    walking = fet['within_walking_dist']
                    cycling = fet['within_cycling_dist']
                    ov = fet['within_ov_dist']
                    outside = fet['outside_influence']

                    summary_text = ['%s totaal huishoudens' % total,
                                    '%s  huishoudens op loopafstand' % walking,
                                    '%s  huishoudens op fietsafstand' % cycling,
                                    '%s  huishoudens op dichtbij openbaar vervoer' % ov,
                                    '%s  huishoudens ver weg' % outside]

                    self.setTextField('locationSummaryText', summary_text)

    def updateDevelopmentAttributeTable(self):
        development = self.dlg.getDevelopment()
        development_field_links = {'Leegstanden': {'Name': 'site_name',
                                                          'Size': 'area',
                                                          'Accessibility': 'max_accessibility'},
                                   'Plancapaciteit': {'Name': 'site_name',
                                                      'Size': 'area',
                                                      'Accessibility': 'max_accessibility'}}

        self.updateTable('Development_locations',
                         'locationAttributeTable',
                         development_field_links[development])

    ###
    # Koppelingen
    def loadKnoppelingenLayers(self):
        pass

    def showOverbelast(self):
        overbelast = self.dlg.getOverbelast()
        overbelast_layers = {'in- en uitstappers': ['Knooppunten','loop', 'fiets'],
                              'fietsenstallingen': ['loop', 'fiets'],
                              'perrons': ['loop', 'fiets'],
                              'stijgpunten': ['loop', 'fiets'],
                              'loopstromen': ['loop', 'fiets'],
                              'all': ['Knooppunten', 'loop', 'fiets']}

        if self.dlg.overbelastShowCheck.isChecked():
            self.setLayerVisible(overbelast_layers['all'], False)
            self.setLayerVisible(overbelast_layers[overbelast], True)
        else:
            self.setLayerVisible(overbelast_layers['all'], False)

    def showRoutes(self):
        routes_layers = ['Ov_routes']

        #if self.dlg.routesShowCheck.isChecked():
        #    self.showLayersInCanvas(routes_layers)
            # self.updateTable('spoor', 'overlapAttributeTable')
        #else:
        #    self.hideLayersInCanvas(routes_layers)
            # self.dlg.hideDataTable('overlapAttributeTable')

    def showImportant(self):
        # locations = self.dlg.getLocations()
        # locations_layers = {'Belangrijk locaties': ['ov_frequency', 'station_isochrones'],
        #                     'Magneten': ['wlo_40_laag'],
        #                     'all': ['ov_frequency', 'station_isochrones', 'wlo_40_laag']}
        #
        # if self.dlg.importantShowCheck.isChecked():
        #     self.hideLayersInCanvas(locations_layers['all'])
        #     self.showLayersInCanvas(locations_layers[locations])
        # else:
        #     self.hideLayersInCanvas(locations_layers['all'])
        pass

    def updateImportantAttributeTable(self):
        # self.updateTable('spoor', 'importantAttributeTable')
        pass

    ###
    # Mobiliteit
    def loadMobiliteitLayers(self):
        pass

    def showWalkIsochrones(self, onoff):
        self.setLayerVisible('Isochronen lopen', onoff)

    def showBikeIsochrones(self, onoff):
        self.setLayerVisible('Isochronen fiets', onoff)

    def showOVIsochrones(self, onoff):
        self.setLayerVisible('Isochronen tram', onoff)
        self.setLayerVisible('Isochronen metro', onoff)
        self.setLayerVisible('Isochronen bus', onoff)

    def showPTAL(self, onoff):

        self.setLayerVisible('Isochronen fiets', onoff)

    def showStopFrequency(self,onoff):
        stops = self.dlg.getStops()
        stop_layers = {'All OV stops': 'bus stop frequency',
                            'Bus stop': 'bus stop frequency',
                            'Tram stop': 'bus stop frequency',
                            'Metro stop': 'bus stop frequency',
                            'Rail stop': 'bus stop frequency',
                            'Ferry stop': 'bus stop frequency',
                            'all': 'bus stop frequency'}
        if self.dlg.stopFrequencyCheck.isChecked():
            self.setLayerVisible(stop_layers['all'], False)
            self.setLayerVisible(stop_layers[stops], True)
        else:
            self.setLayerVisible(stop_layers['all'], False)

    def updateStopSummaryTable(self):
        pass

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

    def setFeatureSelection(self, features, layer_name):
        layer = self.data_layers[layer_name]
        if features:
            if layer.isValid():
                layer.setSelectedFeatures(features)

    def setExtentToLayer(self, layer_name):
        layer = self.data_layers[layer_name]
        if layer.isValid():
            self.canvas.setExtent(layer.extent())
            self.canvas.refresh()

    def setExtentToSelection(self, layer_name):
        layer = self.data_layers[layer_name]
        if layer.isValid():
            if layer.selectedFeatures():
                self.canvas.setExtent(layer.boundingBoxOfSelected())
                self.canvas.refresh()
