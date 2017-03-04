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
from PyQt4.QtCore import pyqtSignal

FORM_CLASS, _ = uic.loadUiType(os.path.join(
    os.path.dirname(__file__), 'kpo_datasysteem_pilot_dockwidget_base.ui'))


class KPOpilotDockWidget(QtGui.QDockWidget, FORM_CLASS):
    # set dialog user signals
    closingPlugin = pyqtSignal()
    tabChanged = pyqtSignal(int)
    # knooppunten
    scenarioChanged = pyqtSignal(str)
    scenarioShow = pyqtSignal(bool)
    isochronesShow = pyqtSignal(bool)
    todLevelChanged = pyqtSignal(int)
    knooppuntChanged = pyqtSignal(str)
    knooppuntShow = pyqtSignal(bool)
    knooppuntSelected = pyqtSignal(str)
    # verstedelijking
    intensityChanged = pyqtSignal(str)
    intensityShow = pyqtSignal(bool)
    intensityLevelChanged = pyqtSignal(int)
    accessibilityShow = pyqtSignal(bool)
    accessibilityLevelChanged = pyqtSignal(int)
    planChanged = pyqtSignal(str)
    planShow = pyqtSignal(bool)
    planSelected = pyqtSignal(int)
    # koppelingen
    stationAttibuteChanged = pyqtSignal(str)
    stationShow = pyqtSignal(bool)
    stationSelected = pyqtSignal(str)
    locationChanged = pyqtSignal(str)
    locationShow = pyqtSignal(bool)
    locationSelected = pyqtSignal(int)
    # mobiliteit
    isochroneWalkShow = pyqtSignal(bool)
    isochroneBikeShow = pyqtSignal(bool)
    isochroneOVShow = pyqtSignal(bool)
    ptalShow = pyqtSignal(bool)
    frequencyChanged = pyqtSignal(str)
    stopsChanged = pyqtSignal(str)
    stopsShow = pyqtSignal(bool)
    stopsSelected = pyqtSignal(int)

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

        # set-up dialog defaults
        #  Knooppunten
        self.scenarioSelectCombo.setCurrentIndex(0)
        self.scenarioShowCheck.setChecked(True)
        self.isochronesShowCheck.setChecked(False)
        self.activateTODLevel(False)
        self.todPolicySlider.setValue(0)
        self.knooppuntenAttributeCombo.setCurrentIndex(0)
        self.knooppuntenShowCheck.setChecked(True)
        #

        # set-up UI interaction signals
        self.vragenTabWidget.currentChanged.connect(self.changeQuestionTab)

        #  Knooppunten
        self.scenarioSelectCombo.currentIndexChanged.connect(self.setScenario)
        self.scenarioShowCheck.stateChanged.connect(self.showScenario)
        self.isochronesShowCheck.stateChanged.connect(self.showIsochrones)
        self.todPolicySlider.valueChanged.connect(self.updateTODLevel)
        self.knooppuntenAttributeCombo.currentIndexChanged.connect(self.setKnooppuntKenmerk)
        self.knooppuntenShowCheck.stateChanged.connect(self.showKnooppunt)
        self.knooppuntenSummaryTable.itemSelectionChanged.connect(self.setKnooppunt)
        # Verstedelijking
        # self.intensitySelectCombo.activated.connect(self.setIntensityValueSlider)
        # self.intensitySelectCombo.activated.connect(self.setAccessibilityValueSlider)
        # self.intensitySelectCombo.activated.connect(self.showIntensity)
        # self.intensityShowCheck.stateChanged.connect(self.showIntensity)
        # self.intensityValueSlider.valueChanged.connect(self.setIntensityValueSlider)
        # self.accessibilityValueSlider.valueChanged.connect(self.setAccessibilityValueSlider)
        # self.locationSelectCombo.activated.connect(self.updateDevelopmentSummaryText)
        # self.locationSelectCombo.activated.connect(self.updateDevelopmentAttributeTable)
        # self.locationSelectCombo.activated.connect(self.showDevelopments)
        # self.locationShowCheck.stateChanged.connect(self.showDevelopments)
        # Koppelingen
        # self.overbelastAttributeCombo.activated.connect(self.showOverbelast)
        # self.overbelastShowCheck.stateChanged.connect(self.showOverbelast)
        # self.importantSelectCombo.activated.connect(self.updateImportantAttributeTable)
        # self.importantSelectCombo.activated.connect(self.showImportant)
        # self.importantShowCheck.stateChanged.connect(self.showImportant)
        # Mobiliteit
        self.isochroneWalkCheck.stateChanged.connect(self.showWalk)
        self.isochroneBikeCheck.stateChanged.connect(self.showBike)
        self.isochroneOvCheck.stateChanged.connect(self.showOV)
        self.ptalSelectCombo.activated.connect(self.showPTAL)
        self.ptalShowCheck.stateChanged.connect(self.showPTAL)
        self.frequencyTimeCombo.currentIndexChanged.connect(self.setTimePeriod)
        self.stopSelectCombo.currentIndexChanged.connect(self.setStopType)
        self.stopFrequencyCheck.stateChanged.connect(self.showStops)
        self.stopSummaryTable.itemSelectionChanged.connect(self.setStops)

        # some globals
        self.current_tab = 0

    #####
    # Main
    def closeEvent(self, event):
        self.closingPlugin.emit()
        event.accept()

    def changeQuestionTab(self, tab_id):
        # make changes if not visiting the introduction
        # and if not returning to the same tab as before
        if tab_id > 0 and tab_id != self.current_tab:
            self.current_tab = tab_id
            self.tabChanged.emit(self.current_tab)

    def resetQuestionTab(self):
        self.vragenTabWidget.setCurrentIndex(0)
        self.current_tab = 0

    #####
    # Knooppunten
    def setScenario(self):
        scenario_name = self.scenarioSelectCombo.currentText()
        self.scenarioChanged.emit(scenario_name)
        if scenario_name == 'Huidige situatie':
            self.activateTODLevel(False)
        else:
            self.activateTODLevel(True)

    def getScenario(self):
        return self.scenarioSelectCombo.currentText()

    def isScenarioVisible(self):
        return self.scenarioShowCheck.isChecked()

    def showScenario(self, state):
        self.scenarioShow.emit(state)

    def isIsochronesVisible(self):
        return self.isochronesShowCheck.isChecked()

    def showIsochrones(self, state):
        self.isochronesShow.emit(state)

    def activateTODLevel(self, onoff):
        self.todPolicyLabel.setEnabled(onoff)
        self.todPolicySlider.setEnabled(onoff)
        self.todPolicyValueLabel.setEnabled(onoff)
        if onoff == False:
            self.todPolicySlider.setValue(0)

    def getTODLevel(self):
        value = self.todPolicySlider.value()
        if value == 1:
            tod_level = 50
        elif value == 2:
            tod_level = 100
        else:
            tod_level = 0
        return tod_level

    def updateTODLevel(self, value):
        tod_level = 0
        if value == 1:
            tod_level = 50
        elif value == 2:
            tod_level = 100
        self.todPolicyValueLabel.setText('%d%%' % tod_level)
        self.todLevelChanged.emit(tod_level)

    def updateScenarioSummary(self, data_values):
        text_list = []
        if len(data_values) == 4:
            text_list.append('%d totaal huishouden' % data_values[0])
            text_list.append('%d op loopafstand van knooppunten' % data_values[1])
            text_list.append('%d op fietsafstand van knooppunten' % data_values[2])
            text_list.append('%d buiten invloedsgebied van knooppunten' % data_values[3])
            self.setTextField('scenarioSummaryText', text_list)

    def setKnooppuntKenmerk(self, id):
        attribute = self.knooppuntenAttributeCombo.currentText()
        self.knooppuntChanged.emit(attribute)

    def getKnooppuntKenmerk(self):
        return self.knooppuntenAttributeCombo.currentText()

    def isKnooppuntVisible(self):
        return self.knooppuntenShowCheck.isChecked()

    def showKnooppunt(self, state):
        self.knooppuntShow.emit(state)

    def updateKnooppuntenTable(self, headers, data_values):
        self.populateDataTable('knooppuntenSummaryTable', headers, data_values)

    def setKnooppunt(self):
        current_row = self.knooppuntenSummaryTable.currentRow()
        current_item = self.knooppuntenSummaryTable.item(current_row, 0)
        station_name = current_item.text()
        self.knooppuntSelected.emit(station_name)

    def isKnooppuntSelected(self):
        return self.knooppuntenSummaryTable.isItemSelected()

    #####
    # Verstedelijking
    def getIntensity(self):
        return self.intensitySelectCombo.currentText()


    def updateIntensityValue(self):
        value = str(self.intensityValueSlider.value())
        self.setLabelValue('intensityValueLabel', value)


    def updateAccessibilityValue(self):
        value = str(self.accessibilityValueSlider.value())
        self.setLabelValue('accessibilityValueLabel', value)

    def getDevelopment(self):
        return self.locationSelectCombo.currentText()


    def clearLocationSummary(self):
        self.locationSummaryText.clear()

    #####
    # Koppelingen
    def getOverbelast(self):
        return self.overbelastAttributeCombo.currentText()


    def getLocations(self):
        return self.importantSelectCombo.currentText()

    #####
    # Mobiliteit
    def showWalk(self, state):
        self.isochroneWalkShow.emit(state)

    def showBike(self, state):
        self.isochroneBikeShow.emit(state)

    def showOV(self, state):
        self.isochroneOVShow.emit(state)

    def showPTAL(self, state):
        self.ptalShow.emit(state)

    def getPTAL(self):
        return self.ptalSelectCombo.currentText()

    def showStops(self, state):
        self.stopsShow.emit(state)

    def setStopType(self):
        attribute = self.stopSelectCombo.currentText()
        self.stopsChanged.emit(attribute)

    def getStops(self):
        return self.stopSelectCombo.currentText()

    def setTimePeriod(self):
        attribute = self.frequencyTimeCombo.currentText()
        self.frequencyChanged.emit(attribute)

    def getTime(self):
        return self.frequencyTimeCombo.currentText()

    def updateStopsTable(self, headers, data_values):
        self.populateDataTable('stopSummaryTable', headers, data_values)

    def setStops(self):
        current_row = self.stopSummaryTable.currentRow()
        current_item = self.stopSummaryTable.item(current_row, 0)
        stop_name = current_item.text()
        self.stopsSelected.emit(stop_name)

    def isStopSelected(self):
        return self.stopSummaryTable.isItemSelected()

    #####
    # General functions
    def setTextField(self, gui_name, text_list):
        field2 = self.findChild(QtGui.QTextEdit, gui_name)
        field2.clear()
        for line in text_list:
            field2.append(line)

    def populateDataTable(self, gui_name, headers, values):
        table = self.findChild(QtGui.QTableWidget, gui_name)
        table.clear()
        columns =  len(headers)
        table.setColumnCount(columns)
        table.setHorizontalHeaderLabels(headers)
        table.setSortingEnabled(False)
        rows = len(values)
        table.setRowCount(rows)
        for i, feature in enumerate(values):
            for j in range(columns):
                entry = QtGui.QTableWidgetItem()
                # the first column is a string
                if j == 0:
                    entry.setText(str(feature[j]))
                else:
                    entry.setData(QtCore.Qt.EditRole, feature[j])
                table.setItem(i, j, entry)
        for m in range(columns-1):
            table.horizontalHeader().setResizeMode(m, QtGui.QHeaderView.ResizeToContents)
        table.horizontalHeader().setResizeMode(columns-1, QtGui.QHeaderView.Stretch)
        table.resizeRowsToContents()
        table.setSortingEnabled(True)

    def setSliderRange(self, gui_name, min, max, step):
        slider = self.findChild(QtGui.QSlider, gui_name)
        slider.setRange(min, max)
        slider.setSingleStep(step)
