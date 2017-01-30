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

import os

from PyQt4 import QtCore, QtGui, uic

from qgis.core import *
from qgis.gui import *

from PyQt4.QtCore import QFileInfo, QTimer, SIGNAL

class KPOExplorer():

    def __init__(self, iface, dockwidget, plugin_dir):

        self.iface = iface
        self.dlg = dockwidget
        self.plugin_dir = plugin_dir
        self.canvas = self.iface.mapCanvas()
        self.legend = self.iface.legendInterface()
        self.timerMapTips = QTimer(self.canvas)
        self.tip = QgsMapTip()
        self.dlg.connect(self.canvas, SIGNAL("xyCoordinates(const QgsPoint&)"),
                     self.mapTipXYChanged)
        self.dlg.connect(self.timerMapTips, SIGNAL("timeout()"),
                     self.showMapTip)

        self.dlg.visibilityChanged.connect(self.onShow)

        # Knooppunten
        self.dlg.scenarioSelectCombo.activated.connect(self.updateScenarioSummaryText)
        self.dlg.scenarioSelectCombo.activated.connect(self.showScenario)
        self.dlg.scenarioShowCheck.stateChanged.connect(self.showScenario)
        self.dlg.knooppuntenAttributeCombo.activated.connect(self.updateKnooppuntenSummaryTable)
        self.dlg.knooppuntenAttributeCombo.activated.connect(self.showKnooppunten)
        self.dlg.knooppuntenShowCheck.stateChanged.connect(self.showKnooppunten)
        self.dlg.knooppuntenChartButton.clicked.connect(self.showKnooppuntenChart)

        # Verstedelijking
        self.dlg.intensitySelectCombo.activated.connect(self.setIntensityValueSlider)
        self.dlg.intensitySelectCombo.activated.connect(self.setAccessibilityValueSlider)
        self.dlg.intensitySelectCombo.activated.connect(self.showIntensity)
        self.dlg.intensityShowCheck.stateChanged.connect(self.showIntensity)
        self.dlg.intensityValueSlider.valueChanged.connect(self.setIntensityValueSlider)
        self.dlg.accessibilityValueSlider.valueChanged.connect(self.setAccessibilityValueSlider)
        self.dlg.locationSelectCombo.activated.connect(self.updateLocationSummaryText)
        self.dlg.locationSelectCombo.activated.connect(self.updateLocationAttributeTable)
        self.dlg.locationSelectCombo.activated.connect(self.showLocations)
        self.dlg.locationShowCheck.stateChanged.connect(self.showLocations)
        self.dlg.locationChartButton.clicked.connect(self.showLocationChart)

        # Koppelingen
        self.dlg.overbelastAttributeCombo.activated.connect(self.showOverbelast)
        self.dlg.overbelastShowCheck.stateChanged.connect(self.showOverbelast)
        self.dlg.routesShowCheck.stateChanged.connect(self.showRoutes)
        self.dlg.importantSelectCombo.activated.connect(self.updateImportantAttributeTable)
        self.dlg.importantSelectCombo.activated.connect(self.showImportant)
        self.dlg.importantShowCheck.stateChanged.connect(self.showImportant)
        self.dlg.importantChartButton.clicked.connect(self.showImportantChart)

        # Mobiliteit
        self.dlg.isochroneWalkCheck.stateChanged.connect(self.showWalk)
        self.dlg.isochroneWalkCheck.stateChanged.connect(self.showCycling)
        self.dlg.isochroneWalkCheck.stateChanged.connect(self.showOV)
        self.dlg.ptalSelectCombo.activated.connect(self.showPTAL)
        self.dlg.ptalShowCheck.stateChanged.connect(self.showPTAL)
        self.dlg.linkSelectCombo.activated.connect(self.showLinkFrequency)
        self.dlg.linkFrequencyCheck.stateChanged.connect(self.showLinkFrequency)
        self.dlg.stopSelectCombo.activated.connect(self.showStopFrequency)
        self.dlg.stopFrequencyCheck.stateChanged.connect(self.showStopFrequency)
        self.dlg.frequencyTimeCombo.activated.connect(self.updateStopSummaryTable)


    def onShow(self):
        self.readDataModel()

        # Knooppunten
        self.showIntensity()
        self.updateScenarioSummaryText()
        self.showKnooppunten()
        self.updateKnooppuntenSummaryTable()

        # Verstedelijking
        self.dlg.updateIntensityValue()
        self.dlg.updateAccessibilityValue()
        self.updateLocationSummaryText()
        self.updateLocationAttributeTable()

        # Koppelingen
        self.showOverbelast()
        self.showRoutes()
        self.showImportant()
        self.updateImportantAttributeTable()

        # Mobiliteit
        self.showWalk()
        self.showCycling()
        self.showOV()
        self.showPTAL()
        self.showLinkFrequency()
        self.showStopFrequency()
        self.updateStopSummaryTable()



    def readDataModel(self):
        project_path = self.plugin_dir + '/data/kpo_datasysteem_sample.qgs'
        self.iface.addProject(project_path)


    def getModelLayers(self, geom='all', provider='all'):
        """Return list of valid QgsVectorLayer in QgsMapCanvas, with specific geometry type and/or data provider"""
        layers_list = []
        for layer in iface.mapCanvas().layers():
            add_layer = False
            if layer.isValid() and layer.type() == QgsMapLayer.VectorLayer:
                if layer.hasGeometryType() and (geom is 'all' or layer.geometryType() in geom):
                    if provider is 'all' or layer.dataProvider().name() in provider:
                        add_layer = True
            if add_layer:
                layers_list.append(layer)
        return layers_list


    '''Knooppunten'''
    def updateScenarioSummaryText(self):
        scenario = self.dlg.getScenario()
        scenario_summary = {'Current scenario':{'total':45324, 'walking':100, 'cycling':30, 'outside':10},
                            'WLO Hoog 2040': {'total':100, 'walking':90, 'cycling':325, 'outside':10},
                            'WLO Laag 2040': {'total':200, 'walking':100, 'cycling':60, 'outside':10},
                            'Primus': {'total':3430, 'walking':100, 'cycling':88, 'outside':10}}

        if self.dlg.language == 'dutch':
            summary_text = ['%i  totaal huishoudens' % scenario_summary[scenario]['total'],
                            '%i  huishoudens op loopafstand' % scenario_summary[scenario]['walking'],
                            '%i  huishoudens op loopafstand' % scenario_summary[scenario]['cycling'],
                            '%i  huishoudens op loopafstand' % scenario_summary[scenario]['outside']]

        self.setTextField('scenarioSummaryText', summary_text)


    def showScenario(self):
        scenario = self.dlg.getScenario()
        scenario_layers = {'Current scenario': ['Invloedsgebieden', 'loop', 'fiets'],
                           'WLO Hoog 2040': ['loop', 'fiets'],
                           'WLO Laag 2040': ['Housing_demand_scenarios', 'loop', 'fiets'],
                           'Primus': ['loop', 'fiets'],
                           'all': ['Housing_demand_scenarios', 'loop', 'fiets']} # These are all the scenario associated layers

        if self.dlg.scenarioShowCheck.isChecked():
            self.hideLayersInCanvas(scenario_layers['all'])
            self.showLayersInCanvas(scenario_layers[scenario])
        else:
            self.hideLayersInCanvas(scenario_layers['all'])


    def updateKnooppuntenSummaryTable(self):
        self.updateTable('spoor', 'knooppuntenSummaryTable')


    def showKnooppunten(self):
        knooppunten = self.dlg.getKnooppunt()
        knooppunten_layers = {'in- en uitstappers': ['Knooppunten','loop', 'fiets'],
                              'fietsenstallingen': ['loop', 'fiets'],
                              'perrons': ['loop', 'fiets'],
                              'stijgpunten': ['loop', 'fiets'],
                              'loopstromen': ['loop', 'fiets'],
                              'all': ['Knooppunten', 'loop', 'fiets']} # These are all the knooppunt associated layers

        if self.dlg.knooppuntenShowCheck.isChecked():
            self.hideLayersInCanvas(knooppunten_layers['all'])
            self.showLayersInCanvas(knooppunten_layers[knooppunten])
        else:
            self.hideLayersInCanvas(knooppunten_layers['all'])


    def showKnooppuntenChart(self):
        pass


    '''Verstedelijking'''
    def showIntensity(self):
        intensity = self.dlg.getIntensity()
        intensity_layers = {'all population': ['ov_stops', 'station_isochrones'],
                            'residents': ['ov_stops'],
                            'workers': ['station_isochrones'],
                            'students': [],
                            'property value (WOZ)': [],
                            'built density': [],
                            'all' : ['ov_stops', 'station_isochrones']}

        if self.dlg.intensityShowCheck.isChecked():
            self.hideLayersInCanvas(intensity_layers['all'])
            self.showLayersInCanvas(intensity_layers[intensity])
        else:
            self.hideLayersInCanvas(intensity_layers['all'])


    def setIntensityValueSlider(self):
        self.dlg.setSliderRange('intensityValueSlider', 0, 100, 10)
        self.dlg.updateIntensityValue()


    def setAccessibilityValueSlider(self):
        self.dlg.setSliderRange('accessibilityValueSlider', 0, 8, 1)
        self.dlg.updateAccessibilityValue()


    def showLocations(self):
        location = self.dlg.getLocation()
        location_layers = {'Plancapaciteit': ['ov_frequency', 'station_isochrones'],
                           'Leegstanden': ['wlo_40_laag'],
                           'all': ['ov_frequency', 'station_isochrones','wlo_40_laag']}

        if self.dlg.locationShowCheck.isChecked():
            self.hideLayersInCanvas(location_layers['all'])
            self.showLayersInCanvas(location_layers[location])
        else:
            self.hideLayersInCanvas(location_layers['all'])


    def updateLocationSummaryText(self):
        location = self.dlg.getLocation()
        location_summary = {'Plancapaciteit': {'total': 45324, 'walking': 100, 'cycling': 30, 'outside': 10},
                            'Leegstanden': {'total': 100, 'walking': 90, 'cycling': 325, 'outside': 10}}

        if self.dlg.language == 'dutch':
            summary_text = ['%i  totaal huishoudens' % location_summary[location]['total'],
                            '%i  huishoudens op loopafstand' % location_summary[location]['walking']]

        self.setTextField('locationSummaryText', summary_text)


    def updateLocationAttributeTable(self):
        self.updateTable('spoor', 'locationAttributeTable')


    def showLocationChart(self):
        pass


    '''Koppelingen'''
    def showOverbelast(self):
        overbelast = self.dlg.getOverbelast()
        overbelast_layers = {'in- en uitstappers': ['ov_stops', 'station_isochrones'],
                              'fietsenstallingen': ['ov_stops'],
                              'perrons': ['station_isochrones'],
                              'stijgpunten': [],
                              'loopstromen': ['ov_stops', 'station_isochrones'],
                              'all': ['ov_stops', 'station_isochrones']}

        if self.dlg.overbelastShowCheck.isChecked():
            self.hideLayersInCanvas(overbelast_layers['all'])
            self.showLayersInCanvas(overbelast_layers[overbelast])
        else:
            self.hideLayersInCanvas(overbelast_layers['all'])


    def showRoutes(self):
        routes_layers = ['ov_stops', 'station_isochrones']

        if self.dlg.routesShowCheck.isChecked():
            self.showLayersInCanvas(routes_layers)
            self.updateTable('spoor', 'overlapAttributeTable')
        else:
            self.hideLayersInCanvas(routes_layers)
            self.dlg.hideDataTable('overlapAttributeTable')


    def showImportant(self):
        locations = self.dlg.getLocations()
        locations_layers = {'Belangrijk locaties': ['ov_frequency', 'station_isochrones'],
                            'Magneten': ['wlo_40_laag'],
                            'all': ['ov_frequency', 'station_isochrones', 'wlo_40_laag']}

        if self.dlg.importantShowCheck.isChecked():
            self.hideLayersInCanvas(locations_layers['all'])
            self.showLayersInCanvas(locations_layers[locations])
        else:
            self.hideLayersInCanvas(locations_layers['all'])


    def updateImportantAttributeTable(self):
        self.updateTable('spoor', 'importantAttributeTable')


    def showImportantChart(self):
        pass


    '''Bereikbaarheid'''
    def showWalk(self):
        if self.dlg.isochroneWalkCheck.isChecked():
            self.showLayersInCanvas('station_isochrones')
        else:
            self.hideLayersInCanvas('station_isochrones')


    def showCycling(self):
        if self.dlg.isochroneBikeCheck.isChecked():
            self.showLayersInCanvas('station_isochrones')
        else:
            self.hideLayersInCanvas('station_isochrones')


    def showOV(self):
        if self.dlg.isochroneOvCheck.isChecked():
            self.showLayersInCanvas('station_isochrones')
        else:
            self.hideLayersInCanvas('station_isochrones')


    def showPTAL(self):
        ptal = self.dlg.getPTAL()
        if self.dlg.ptalShowCheck.isChecked():
            self.showLayersInCanvas(ptal)
        else:
            self.hideLayersInCanvas(ptal)


    def showLinkFrequency(self):
        links = self.dlg.getLinks()
        if self.dlg.linkFrequencyCheck.isChecked():
            self.showLayersInCanvas(links)
        else:
            self.hideLayersInCanvas(links)


    def showStopFrequency(self):
        stops = self.dlg.getStops()
        if self.dlg.ptalShowCheck.isChecked():
            self.showLayersInCanvas(stops)
        else:
            self.hideLayersInCanvas(stops)


    def updateStopSummaryTable(self):
        time = self.dlg.getTime()
        self.updateTable('spoor', 'stopSummaryTable')


    '''General'''
    # MapTip setup
    def mapTipXYChanged(self, p):
        if self.canvas.underMouse():  # Only if mouse is over the map
            # Here you could check if your custom MapTips button is active or sth
            self.lastMapPosition = QgsPoint(p.x(), p.y())
            self.tip.clear(self.canvas)
            self.timerMapTips.start(750)  # time in milliseconds


    def showMapTip(self):
        self.timerMapTips.stop()

        layer = self.iface.activeLayer()

        if self.canvas.underMouse():
            pointQgs = self.lastMapPosition
            pointQt = self.canvas.mouseLastXY()
            self.tip.showMapTip(layer, pointQgs, pointQt, self.canvas)


    # Selecting
    def setFeatureSelection(self, features, layer):
        if features:
            if layer.isValid():
                layer.setSelectedFeatures(features)

    # Canvas control
    def setExtentToLayer(self,layer):
        if layer.isValid():
            self.canvas.setExtent(layer.extent())
            self.canvas.refresh()


    def setExtentToSelection(self,layer):
        if layer.isValid():
            if layer.selectedFeatures():
                self.canvast.setExtent(layer.boundingBoxOfSelected())
                self.canvas.refresh()


    def showLayersInCanvas(self, layers):
        current_layers = self.legend.layers()
        for layer in current_layers:
            if layer.name() in layers:
                self.legend.setLayerVisible(layer, True)



    def hideLayersInCanvas(self, layers):
        current_layers = self.legend.layers()
        for layer in current_layers:
            if layer.name() in layers:
                self.legend.setLayerVisible(layer, False)


    # Data reading
    def getLayerByName(self, name):
        layer = None
        for i in QgsMapLayerRegistry.instance().mapLayers().values():
            if i.name() == name:
                layer = i
        return layer

    def getFeatureValue(self, layer, id_field, id, value_field):
        exp = QgsExpression('%s = %s' % (id_field, id))
        request = QgsFeatureRequest(exp)
        fet = layer.getFeatures(request)
        value = fet[value_field]

        return value


    def setTextField(self, gui_name, text_list):
        self.dlg.setTextField(gui_name, text_list)


    def setLabelValue(self, gui_name, value):
        self.dlg.setLabelValue(gui_name, value)


    def setDataTable(self, gui_name, row, column, entry):
        self.dlg.setDataTableField(gui_name, row, column, entry)


    def updateTable(self, data_layer, gui_name):
        layer = self.getLayerByName(data_layer)
        layer_fields = [field.name() for field in layer.fields()]
        self.dlg.setDataTableSize(gui_name, layer.featureCount())

        table_headers = self.dlg.getDataTableHeaders(gui_name)

        for row, fet in enumerate(layer.getFeatures()):
            for column, name in enumerate(table_headers):
                if name in layer_fields:
                    if fet[name]:
                        self.dlg.setDataTableField(gui_name, row, column, fet[name])

