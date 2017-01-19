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

from PyQt4 import QtGui, uic
from PyQt4.QtCore import pyqtSignal

FORM_CLASS, _ = uic.loadUiType(os.path.join(
    os.path.dirname(__file__), 'kpo_datasysteem_pilot_dockwidget_base.ui'))


class KPOpilotDockWidget(QtGui.QDockWidget, FORM_CLASS):

    closingPlugin = pyqtSignal()

    def __init__(self, parent=None):
        """Constructor."""
        super(KPOpilotDockWidget, self).__init__(parent)
        # Set up the user interface from Designer.
        # After setupUI you can access any designer object by doing
        # self.<objectname>, and you can use autoconnect slots - see
        # http://qt-project.org/doc/qt-4.8/designer-using-a-ui-file.html
        # #widgets-and-dialogs-with-auto-connect
        self.setupUi(self)

        self.plugin_dir = os.path.dirname(__file__)
        self.logosLabel.setPixmap(QtGui.QPixmap(self.plugin_dir + '/images/partner_logos.png'))

        # Dictionary containing all language in type/element/naming structure
        self.language = 'dutch'
        self.gui_name_dutch = {
            'housingDemandBox': 'Huisaanbod',
            'knooppuntenStatusBox': 'Knooppunten status',
            'scenarioSelectBox': ['Huidig scenario',
                                  'WLO Laag 2040',
                                  'WLO Hoog 2040',
                                  'Primus'],
            'knooppuntenAttributeCombo': ['In- en uitstappers',
                                          'fietsstallingen',
                                          'perrons',
                                          'stijgpunten',
                                          'loopstromen']}

        self.gui_naming_english = {}


    '''General'''
    # Updating GUI elements
    def setLanguage(self):
        for widget in self.children():
            name = widget.objectName()
            if name in self.gui_name_dutch.keys():
                if isinstance(widget, QComboBox):
                    widget.addItems(self.gui_name_dutch[name])
                if isinstance(widget, QGroupBox):
                    pass

    def setComboBox(self):
        if self.language = 'dutch':
            scenarios = self.gui_name_dutch[]
            self.scenarioSelectCombo.addItems(self.gui_name_dutch)

    def setTableField(self, gui_name, dict):
        pass

    def setTextField(self, gui_name, list):
        pass

    def setValue(self, gui_name, integer):
        pass


    def closeEvent(self, event):
        self.closingPlugin.emit()
        event.accept()


    def ifShow(self):
        pass


    '''Knooppunten'''
    def onShowKnooppunten(self):
        pass


    def setScenarioSelectCombo(self,scenarios):
        scenarios = ['Huiding scenario', ]
            self.networkCombo.clear()
            self.networkCombo.addItems(scenarios)


    def updateScenarioSummaryText(self,scenario_summary):
        pass


    def showScenario(self):
        pass


    def hideScenario(self):
        pass


    def setKnooppuntenAttributeCombo(self):
        pass


    def showKnooppuntenAttribute(self):
        pass


    def hideKnooppuntenAttribute(self):
        pass


    def updateKnooppuntenSummaryTable(self):
        pass

    def showKnooppuntenSummaryGraph(self):
        pass

    '''Verstedelijking'''


    '''Koppelingen'''


    '''Bereikbaarheid'''







    # def getSelectedLayer(self):
    #     layer_id = self.layersCombo.currentSlection()
    #     return layer_id
    #
    # def setLayersList(self, layers_list):
    #     self.layersCombo.clear()
    #     self.layersCombo.setText(layers_list)