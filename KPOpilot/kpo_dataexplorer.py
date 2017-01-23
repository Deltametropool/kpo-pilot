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

import os.path

from . import utility_functions as uf

class KPOExplorer(QtCore.QObject):

    def __init__(self, iface, dockwidget, plugin_dir):

        self.iface = iface
        self.dlg = dockwidget
        self.plugin_dir = plugin_dir
        self.canvas = self.iface.mapCanvas()


        # self.dlg.button.clicked.connect(self.updateLayers)

    '''Initial setup'''
    def readDataModel(self):
        self.iface.project.read(QFileInfo(self.plugin_dir +'data/project.qgs'))


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
    def setKnooppuntenCombo(self):
        pass

    # MapTip setup
    def createMapTip(self, layer, fields, mouse_location):
        self.tip = QgsMapTip()


    def changeMapTip(self):
        pass

    def showMapTip(self):
        if self.canvas.underMouse():

            pointQgs = self.lastMapPosition
            pointQt = self.canvas.mouseLastXY()
            self.canvas.showMapTip(self.layer, pointQgs, pointQt, self.canvas)

    # Selecting

    def setFeatureSelection(self, features, layer):
        if features:
            if layer.isValid():
                layer.setSelectedFeatures(features)



    # Canvas control


    def showScenario(self):
        pass


    def hideScenario(self):
        pass

    '''General'''

    def setExtentToLayer(self,layer):
        if layer.isValid():
            self.canvas.setExtent(layer.extent())
            self.canvas.refresh()

    def setExtentToSelection(self,layer):
        if layer.isValid():
            if layer.selectedFeatures():
                self.canvast.setExtent(layer.boundingBoxOfSelected())
                self.canvas.refresh()

    def addLayersToCanvas(self, layers):
        # add layer to the registry
        self.QgsMapLayerRegistry.instance().addMapLayer(layer)
        # set the map canvas layer set
        self.canvas.setLayerSet([QgsMapCanvasLayer(layer)])

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

    def setDataTable(self, table_widget, row, column, entry):
        table_widget.setItem(row, column, entry)


    '''Knooppunten'''
    def setScenarioSummaryTable(self):



        scenario = self.dlg.getScenario()

        get

    # def updateLayers(self):
    #     layers = []
    #     # fill the list
    #     self.dlg.setLayersList(layers)
    #
    #
    #     self.dlg.layersCombo.clear()
    #     self.dlg.layersCombo.setText(layers)
    #     self.layersCombo.currentSlection()