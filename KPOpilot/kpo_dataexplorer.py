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
        # self.timerMapTips = QTimer(self.canvas)
        # self.tip = QgsMapTip()
        # self.dlg.connect(self.canvas, SIGNAL("xyCoordinates(const QgsPoint&)"),
        #              self.mapTipXYChanged)
        # self.dlg.connect(self.timerMapTips, SIGNAL("timeout()"),
        #              self.showMapTip)
        #
        self.dlg.visibilityChanged.connect(self.onShow)

        # Knooppunten
        self.dlg.scenarioSelectCombo.activated.connect(self.updateScenarioSummaryText)
        self.dlg.scenarioSelectCombo.activated.connect(self.showScenario)
        self.dlg.scenarioShowCheck.stateChanged.connect(self.showScenario)
        self.dlg.knooppuntenAttributeCombo.activated.connect(self.updateKnooppuntenSummaryTable)
        self.dlg.knooppuntenAttributeCombo.activated.connect(self.showKnooppunten)
        self.dlg.knooppuntenShowCheck.stateChanged.connect(self.showKnooppunten)

        # Verstedelijking
        self.dlg.intensitySelectCombo.activated.connect(self.setIntensityValueSlider)
        self.dlg.intensitySelectCombo.activated.connect(self.setAccessibilityValueSlider)
        self.dlg.intensitySelectCombo.activated.connect(self.showIntensity)
        self.dlg.intensityShowCheck.stateChanged.connect(self.showIntensity)
        self.dlg.intensityValueSlider.valueChanged.connect(self.setIntensityValueSlider)
        self.dlg.accessibilityValueSlider.valueChanged.connect(self.setAccessibilityValueSlider)
        self.dlg.locationSelectCombo.activated.connect(self.updateDevelopmentSummaryText)
        self.dlg.locationSelectCombo.activated.connect(self.updateDevelopmentAttributeTable)
        self.dlg.locationSelectCombo.activated.connect(self.showDevelopments)
        self.dlg.locationShowCheck.stateChanged.connect(self.showDevelopments)

        # Koppelingen
        self.dlg.overbelastAttributeCombo.activated.connect(self.showOverbelast)
        self.dlg.overbelastShowCheck.stateChanged.connect(self.showOverbelast)
        #self.dlg.routesShowCheck.stateChanged.connect(self.showRoutes)
        self.dlg.importantSelectCombo.activated.connect(self.updateImportantAttributeTable)
        self.dlg.importantSelectCombo.activated.connect(self.showImportant)
        self.dlg.importantShowCheck.stateChanged.connect(self.showImportant)

        # Mobiliteit
        self.dlg.isochroneWalkCheck.stateChanged.connect(self.showWalk)
        self.dlg.isochroneWalkCheck.stateChanged.connect(self.showCycling)
        self.dlg.isochroneWalkCheck.stateChanged.connect(self.showOV)
        self.dlg.ptalSelectCombo.activated.connect(self.showPTAL)
        self.dlg.ptalShowCheck.stateChanged.connect(self.showPTAL)
        self.dlg.stopSelectCombo.activated.connect(self.showStopFrequency)
        self.dlg.stopFrequencyCheck.stateChanged.connect(self.showStopFrequency)
        self.dlg.frequencyTimeCombo.activated.connect(self.updateStopSummaryTable)


    def onShow(self):
        #self.readDataModel()

        # Knooppunten
        #self.showIntensity()
        #self.updateScenarioSummaryText()
        #self.showKnooppunten()
        #self.updateKnooppuntenSummaryTable()

        # Verstedelijking
        #self.dlg.updateIntensityValue()
        #self.dlg.updateAccessibilityValue()
        #self.updateDevelopmentSummaryText()
        #self.updateDevelopmentAttributeTable()

        # # Koppelingen
        #self.showOverbelast()
        #self.showRoutes()
        #self.showImportant()
        #self.updateImportantAttributeTable()

        # # Mobiliteit
        #self.showWalk()
        #self.showCycling()
        #self.showOV()
        #self.showPTAL()
        #self.showStopFrequency()
        #self.updateStopSummaryTable()



    def readDataModel(self):
        project_path = self.plugin_dir + '/data/kpo_datasysteem.qgs'
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
                            'Primos': {'total':3430, 'walking':100, 'cycling':88, 'outside':10}}

        if self.dlg.language == 'dutch':
            summary_text = ['%i  huishoudens totaal' % scenario_summary[scenario]['total'],
                            '%i  huishoudens op loopafstand' % scenario_summary[scenario]['walking'],
                            '%i  huishoudens op fietsafstand' % scenario_summary[scenario]['cycling'],
                            '%i  huishoudens buiten het invloedsgebied' % scenario_summary[scenario]['outside']]

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


    def updateKnooppuntenSummaryTable(self):
        knooppunten = self.dlg.getKnooppunt()
        knooppunten_field_links = {'in- en uitstappers': {'Station': 'station_name',
                                                          'Value': 'passengers',
                                                          '% change': 'passengers_change'},
                                   'fietsenstallingen': {'Station': 'station_name',
                                                          'Value': 'passengers',
                                                          '% change': 'passengers_change'},
                                   'perrons': {'Station': 'station_name',
                                                          'Value': 'passengers',
                                                          '% change': 'passengers_change'},
                                   'stijgpunten': {'Station': 'station_name',
                                                          'Value': 'passengers',
                                                          '% change': 'passengers_change'},
                                   'loopstromen': {'Station': 'station_name',
                                                          'Value': 'passengers',
                                                          '% change': 'passengers_change'}}
        self.updateTable('Knooppunten', 'knooppuntenSummaryTable', knooppunten_field_links[knooppunten])


    '''Verstedelijking'''
    def showIntensity(self):
        intensity = self.dlg.getIntensity()
        if self.dlg.intensityShowCheck.isChecked():
            self.showLayersInCanvas('Intensity')

        else:
            self.hideLayersInCanvas('Intensity')
            # vl.setSubsetString( 'Counties = "Norwich"' )

    def setIntensityValueSlider(self):
        self.dlg.setSliderRange('intensityValueSlider', 0, 100, 10)
        self.dlg.updateIntensityValue()


    def setAccessibilityValueSlider(self):
        self.dlg.setSliderRange('accessibilityValueSlider', 0, 8, 1)
        self.dlg.updateAccessibilityValue()


    def showDevelopments(self):
        if self.dlg.locationShowCheck.isChecked():
            self.showLayersInCanvas('Development_locations')
        else:
            self.hideLayersInCanvas('Development_locations')


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



    '''Koppelingen'''
    def showOverbelast(self):
        overbelast = self.dlg.getOverbelast()
        overbelast_layers = {'in- en uitstappers': ['Knooppunten','loop', 'fiets'],
                              'fietsenstallingen': ['loop', 'fiets'],
                              'perrons': ['loop', 'fiets'],
                              'stijgpunten': ['loop', 'fiets'],
                              'loopstromen': ['loop', 'fiets'],
                              'all': ['Knooppunten', 'loop', 'fiets']}

        if self.dlg.overbelastShowCheck.isChecked():
            self.hideLayersInCanvas(overbelast_layers['all'])
            self.showLayersInCanvas(overbelast_layers[overbelast])
        else:
            self.hideLayersInCanvas(overbelast_layers['all'])


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


    '''Mobiliteit'''
    def showWalk(self):
        if self.dlg.isochroneWalkCheck.isChecked():
            self.showLayersInCanvas('Isochrones')
        else:
            self.hideLayersInCanvas('Isochrones')


    def showCycling(self):
        if self.dlg.isochroneBikeCheck.isChecked():
            self.showLayersInCanvas('Isochrones')
        else:
            self.hideLayersInCanvas('Isochrones')


    def showOV(self):
        if self.dlg.isochroneOvCheck.isChecked():
            self.showLayersInCanvas('Isochrones')
        else:
            self.hideLayersInCanvas('Isochrones')


    def showPTAL(self):
        ptal = self.dlg.getPTAL()
        ptal_layers = {'Levels': 'Spatial_characteristics copy',
                       'Index': 'Spatial_characteristics copy'}
        if self.dlg.ptalShowCheck.isChecked():
            self.showLayersInCanvas(ptal_layers[ptal])
        else:
            self.hideLayersInCanvas(ptal_layers[ptal])


    def showStopFrequency(self):
        stops = self.dlg.getStops()
        stop_layers = {'All OV stops': 'bus stop frequency',
                            'Bus stop': 'bus stop frequency',
                            'Tram stop': 'bus stop frequency',
                            'Metro stop': 'bus stop frequency',
                            'Rail stop': 'bus stop frequency',
                            'Ferry stop': 'bus stop frequency',
                            'all': 'bus stop frequency'}
        if self.dlg.stopFrequencyCheck.isChecked():
            self.hideLayersInCanvas(stop_layers['all'])
            self.showLayersInCanvas(stop_layers[stops])
        else:
            self.hideLayersInCanvas(stop_layers['all'])


    def updateStopSummaryTable(self):
        time = self.dlg.getTime()
        time_field_links = {'Ochtend spits': {'Stop': '',
                                              'Bus': '',
                                              'Tram': '',
                                              'Metro': '',
                                              'Rail': ''},
                            'Middag dal': {'Stop': '',
                                              'Bus': '',
                                              'Tram': '',
                                              'Metro': '',
                                              'Rail': ''},
                            'Avond spits': {'Stop': '',
                                              'Bus': '',
                                              'Tram': '',
                                              'Metro': '',
                                              'Rail': ''}
                            }

        # self.updateTable('spoor', 'stopSummaryTable')


    '''General'''
    # MapTip setup
    # def mapTipXYChanged(self, p):
    #     if self.canvas.underMouse():  # Only if mouse is over the map
    #         if self.iface.activeLayer():
    #             # Here you could check if your custom MapTips button is active or sth
    #             self.lastMapPosition = QgsPoint(p.x(), p.y())
    #             self.tip.clear(self.canvas)
    #             self.timerMapTips.start(750)  # time in milliseconds
    #
    #
    # def showMapTip(self):
    #     self.timerMapTips.stop()
    #
    #     layer = self.iface.activeLayer()
    #     if layer:
    #         if self.canvas.underMouse():
    #             pointQgs = self.lastMapPosition
    #             pointQt = self.canvas.mouseLastXY()
    #             self.tip.showMapTip(layer, pointQgs, pointQt, self.canvas)


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


    def updateTable(self, data_layer, gui_name, link_dict):
        layer = self.getLayerByName(data_layer)
        if layer.isValid():
            layer_fields = [field.name() for field in layer.fields()]
            self.dlg.setDataTableSize(gui_name, layer.featureCount())

            table_headers = self.dlg.getDataTableHeaders(gui_name)
            for row, fet in enumerate(layer.getFeatures()):
                for column, column_name in enumerate(table_headers):
                    if link_dict[column_name] in layer_fields:
                        self.dlg.setDataTableField(gui_name, row, column, fet[link_dict[column_name]])

