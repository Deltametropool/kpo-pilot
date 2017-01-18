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

    def clearQInterface(self):
        pass

    def openQInterface(self):
        pass

    def readDataModel(self):
        self.iface.project.read(QFileInfo(self.plugin_dir + 'project'))
        return self.iface.project.read() # True if successful

    def createMapTip(self, layer, fields, mouse_location):
        self.tip = QgsMapTip()


    def changeMapTip(self):
        pass

    def showMapTip(self):
        if self.canvas.underMouse():

            pointQgs = self.lastMapPosition
            pointQt = self.canvas.mouseLastXY()
            self.canvas.showMapTip(self.layer, pointQgs, pointQt,
                                   self.canvas)

    def setFeatureSelection(self, features, layer):
        if features:
            if layer.isValid():
                layer.setSelectedFeatures(features)

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
        pass



    # def updateLayers(self):
    #     layers = []
    #     # fill the list
    #     self.dlg.setLayersList(layers)
    #
    #
    #     self.dlg.layersCombo.clear()
    #     self.dlg.layersCombo.setText(layers)
    #     self.layersCombo.currentSlection()