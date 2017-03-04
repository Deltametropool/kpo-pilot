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
    intensityTypeChanged = pyqtSignal(str)
    intensityShow = pyqtSignal(bool)
    intensityLevelChanged = pyqtSignal(int)
    accessibilityShow = pyqtSignal(bool)
    accessibilityLevelChanged = pyqtSignal(int)
    planTypeChanged = pyqtSignal(str)
    planShow = pyqtSignal(bool)
    planSelected = pyqtSignal(str)
    # koppelingen
    stationAttributeChanged = pyqtSignal(str)
    stationShow = pyqtSignal(bool)
    stationSelected = pyqtSignal(str)
    locationTypeChanged = pyqtSignal(str)
    locationShow = pyqtSignal(bool)
    locationSelected = pyqtSignal(str)
    # mobiliteit
    isochroneWalkShow = pyqtSignal(bool)
    isochroneBikeShow = pyqtSignal(bool)
    isochroneOVShow = pyqtSignal(bool)
    ptalChanged = pyqtSignal(str)
    ptalShow = pyqtSignal(bool)
    frequencyChanged = pyqtSignal(str)
    stopsChanged = pyqtSignal(str)
    stopsShow = pyqtSignal(bool)
    stopsSelected = pyqtSignal(str)

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
        self.__activateTODLevel__(False)
        self.todPolicySlider.setValue(0)
        self.knooppuntenAttributeCombo.setCurrentIndex(0)
        self.knooppuntenShowCheck.setChecked(True)

        # Verstedelijking
        self.intensitySelectCombo.setCurrentIndex(0)
        self.intensityShowCheck.setChecked(False)
        self.intensityValueSlider.setValue(7)
        self.accessibilityShowCheck.setChecked(False)
        self.accessibilityValueSlider.setValue(1)
        self.planSelectCombo.setCurrentIndex(0)
        self.planShowCheck.setChecked(False)

        # Koppelingen
        self.overbelastAttributeCombo.setCurrentIndex(0)
        self.overbelastShowCheck.setChecked(True)
        self.locationSelectCombo.setCurrentIndex(0)
        self.locationShowCheck.setChecked(False)

        # Mobiliteit
        self.isochroneWalkCheck.setChecked(True)
        self.isochroneBikeCheck.setChecked(False)
        self.isochroneOvCheck.setChecked(True)
        self.ptalSelectCombo.setCurrentIndex(0)
        self.ptalShowCheck.setChecked(False)
        self.frequencyTimeCombo.setCurrentIndex(0)
        self.stopSelectCombo.setCurrentIndex(0)
        self.stopFrequencyCheck.setChecked(False)

        # set-up UI interaction signals
        self.vragenTabWidget.currentChanged.connect(self.__changeQuestionTab__)

        #  Knooppunten
        self.scenarioSelectCombo.currentIndexChanged.connect(self.__setScenario__)
        self.scenarioShowCheck.stateChanged.connect(self.__showScenario__)
        self.isochronesShowCheck.stateChanged.connect(self.__showIsochrones__)
        self.todPolicySlider.valueChanged.connect(self.__updateTODLevel__)
        self.knooppuntenAttributeCombo.currentIndexChanged.connect(self.__setKnooppuntKenmerk__)
        self.knooppuntenShowCheck.stateChanged.connect(self.__showKnooppunt__)
        self.knooppuntenSummaryTable.itemSelectionChanged.connect(self.__setKnooppunt__)
        # Verstedelijking
        self.intensitySelectCombo.currentIndexChanged.connect(self.__setIntensity__)
        self.intensityShowCheck.stateChanged.connect(self.__showIntensity__)
        self.intensityValueSlider.valueChanged.connect(self.__updateIntensityLevel__)
        self.accessibilityShowCheck.stateChanged.connect(self.__showAccessibility__)
        self.accessibilityValueSlider.valueChanged.connect(self.__updateAccessibilityLevel__)
        self.planSelectCombo.currentIndexChanged.connect(self.__setPlan__)
        self.planShowCheck.stateChanged.connect(self.__showPlan__)
        self.planAttributeTable.itemSelectionChanged.connect(self.__setPlanLocation__)
        # Koppelingen
        self.overbelastAttributeCombo.currentIndexChanged.connect(self.__setStationKenmerk__)
        self.overbelastShowCheck.stateChanged.connect(self.__showStations__)
        self.overbelastAttributeTable.itemSelectionChanged.connect(self.__setStation__)
        self.locationSelectCombo.currentIndexChanged.connect(self.__setLocationType__)
        self.locationShowCheck.stateChanged.connect(self.__showLocations__)
        self.locationAttributeTable.itemSelectionChanged.connect(self.__setLocation__)
        # Mobiliteit
        self.isochroneWalkCheck.stateChanged.connect(self.__showWalk__)
        self.isochroneBikeCheck.stateChanged.connect(self.__showBike__)
        self.isochroneOvCheck.stateChanged.connect(self.__showOV__)
        self.ptalSelectCombo.activated.connect(self.__setPTAL__)
        self.ptalShowCheck.stateChanged.connect(self.__showPTAL__)
        self.frequencyTimeCombo.currentIndexChanged.connect(self.__setTimePeriod__)
        self.stopSelectCombo.currentIndexChanged.connect(self.__setStopType__)
        self.stopFrequencyCheck.stateChanged.connect(self.__showStops__)
        self.stopSummaryTable.itemSelectionChanged.connect(self.__setStops__)

        # some globals
        self.current_tab = 0

    #####
    # Main
    def closeEvent(self, event):
        self.closingPlugin.emit()
        event.accept()

    def __changeQuestionTab__(self, tab_id):
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
    # Methods for Woonscenario
    def __setScenario__(self):
        scenario_name = self.scenarioSelectCombo.currentText()
        self.scenarioChanged.emit(scenario_name)
        if scenario_name == 'Huidige situatie':
            self.__activateTODLevel__(False)
        else:
            self.__activateTODLevel__(True)

    def getScenario(self):
        return self.scenarioSelectCombo.currentText()

    def isScenarioVisible(self):
        return self.scenarioShowCheck.isChecked()

    def __showScenario__(self, state):
        self.scenarioShow.emit(state)

    def isIsochronesVisible(self):
        return self.isochronesShowCheck.isChecked()

    def __showIsochrones__(self, state):
        self.isochronesShow.emit(state)

    # Methods for TOD level
    def __activateTODLevel__(self, onoff):
        self.todPolicyLabel.setEnabled(onoff)
        self.todPolicySlider.setEnabled(onoff)
        self.todPolicyValueLabel.setEnabled(onoff)
        if not onoff:
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

    def __updateTODLevel__(self, value):
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
            self.__setTextField__('scenarioSummaryText', text_list)

    # Methods for Knooppunten
    def __setKnooppuntKenmerk__(self):
        attribute = self.knooppuntenAttributeCombo.currentText()
        self.knooppuntChanged.emit(attribute)

    def getKnooppuntKenmerk(self):
        return self.knooppuntenAttributeCombo.currentText()

    def isKnooppuntVisible(self):
        return self.knooppuntenShowCheck.isChecked()

    def __showKnooppunt__(self, state):
        self.knooppuntShow.emit(state)

    def updateKnooppuntenTable(self, headers, data_values):
        self.__populateDataTable__('knooppuntenSummaryTable', headers, data_values)

    def __setKnooppunt__(self):
        current_row = self.knooppuntenSummaryTable.currentRow()
        current_item = self.knooppuntenSummaryTable.item(current_row, 0)
        station_name = current_item.text()
        self.knooppuntSelected.emit(station_name)

    def isKnooppuntSelected(self):
        return self.knooppuntenSummaryTable.isItemSelected()

    #####
    # Verstedelijking
    # Methods for opportunities
    def __showIntensity__(self, state):
        self.intensityShow.emit(state)

    def isIntensityVisible(self):
        return self.intensityShowCheck.isChecked()

    def __setIntensity__(self):
        attribute = self.intensitySelectCombo.currentText()
        self.intensityTypeChanged.emit(attribute)

    def getIntensityType(self):
        return self.intensitySelectCombo.currentText()

    def getIntensityLevel(self):
        value = self.intensityValueSlider.value()
        return value

    def __updateIntensityLevel__(self, value):
         self.todLevelChanged.emit(value)

    def updateIntensityLabel(self, intensity_label):
        self.intesityValueLabel.setText('%d%%' % intensity_label)

    def __showAccessibility__(self, state):
        self.accessibilityShow.emit(state)

    def isAccessibilityVisible(self):
        return self.accessibilityShowCheck.isChecked()

    def getAccessibilityLevel(self):
        value = self.accessibilityValueSlider.value()
        return value

    def __updateAccessibilityLevel__(self, value):
         self.accessibilityLevelChanged.emit(value)

    def updateAccessibilityLabel(self, intensity_label):
        self.accessibilityValueLabel.setText('%d%%' % intensity_label)

    # Methods for plans
    def __showPlan__(self, state):
        self.planShow.emit(state)

    def isPlanVisible(self):
        return self.planShowCheck.isChecked()

    def __setPlan__(self):
        attribute = self.planSelectCombo.currentText()
        self.planTypeChanged.emit(attribute)

    def getPlanType(self):
        return self.planSelectCombo.currentText()

    def updatePlanSummary(self, data_values):
        text_list = []
        if len(data_values) == 3:
            text_list.append('%d totaal woningen' % data_values[0])
            text_list.append('%d in onderbenut bereikbaare locaties' % data_values[1])
            text_list.append('%d buiten onderbenut bereikbaare locaties' % data_values[2])
            self.__setTextField__('planSummaryText', text_list)

    def updatePlanTable(self, headers, data_values):
        self.__populateDataTable__('planAttributeTable', headers, data_values)

    def __setPlanLocation__(self):
        current_row = self.planAttributeTable.currentRow()
        current_item = self.planAttributeTable.item(current_row, 0)
        location_name = current_item.text()
        self.planSelected.emit(location_name)

    def isPlanLocationSelected(self):
        return self.planAttributeTable.isItemSelected()

    #####
    # Koppelingen
    # Methods for Overbelast stations
    def __showStations__(self, state):
        self.stationShow.emit(state)

    def isStationVisible(self):
        return self.overbelastShowCheck.isChecked()

    def __setStationKenmerk__(self):
        attribute = self.overbelastAttributeCombo.currentText()
        self.stationAttributeChanged.emit(attribute)

    def getSationAttribute(self):
        return self.overbelastAttributeCombo.currentText()

    def updateStationsTable(self, headers, data_values):
        self.__populateDataTable__('overbelastAttributeTable', headers, data_values)

    def __setStation__(self):
        current_row = self.overbelastAttributeTable.currentRow()
        current_item = self.overbelastAttributeTable.item(current_row, 0)
        station_name = current_item.text()
        self.stationSelected.emit(station_name)

    def isStationSelected(self):
        return self.overbelastAttributeTable.isItemSelected()

    # Methods for Locaties
    def __showLocations__(self, state):
        self.locationShow.emit(state)

    def isLocationVisible(self):
        return self.locationShowCheck.isChecked()

    def __setLocationType__(self):
        attribute = self.locationSelectCombo.currentText()
        self.locationTypeChanged.emit(attribute)

    def getLocationType(self):
        return self.locationSelectCombo.currentText()

    def updateLocationsTable(self, headers, data_values):
        self.__populateDataTable__('locationAttributeTable', headers, data_values)

    def __setLocation__(self):
        current_row = self.locationAttributeTable.currentRow()
        current_item = self.locationAttributeTable.item(current_row, 0)
        location_name = current_item.text()
        self.locationSelected.emit(location_name)

    def isLocationSelected(self):
        return self.locationAttributeTable.isItemSelected()

    #####
    # Mobiliteit
    # Methods for Isochronen
    def __showWalk__(self, state):
        self.isochroneWalkShow.emit(state)

    def isWalkVisible(self):
        return self.isochroneWalkCheck.isChecked()

    def __showBike__(self, state):
        self.isochroneBikeShow.emit(state)

    def isBikeVisible(self):
        return self.isochroneBikeCheck.isChecked()

    def __showOV__(self, state):
        self.isochroneOVShow.emit(state)

    def isOvVisible(self):
        return self.isochroneOvCheck.isChecked()

    # Methods for Bereikbaarheid
    def __showPTAL__(self, state):
        self.ptalShow.emit(state)

    def isPTALVisible(self):
        return self.ptalShowCheck.isChecked()

    def __setPTAL__(self):
        attribute = self.ptalSelectCombo.currentText()
        self.ptalChanged.emit(attribute)

    def getPTAL(self):
        return self.ptalSelectCombo.currentText()

    # Methods for stops frequency
    def __showStops__(self, state):
        self.stopsShow.emit(state)

    def __setStopType__(self):
        attribute = self.stopSelectCombo.currentText()
        self.stopsChanged.emit(attribute)

    def isStopsVisible(self):
        return self.stopFrequencyCheck.isChecked()

    def getStops(self):
        return self.stopSelectCombo.currentText()

    def __setTimePeriod__(self):
        attribute = self.frequencyTimeCombo.currentText()
        self.frequencyChanged.emit(attribute)

    def getTimePeriod(self):
        return self.frequencyTimeCombo.currentText()

    def updateStopsTable(self, headers, data_values):
        self.__populateDataTable__('stopSummaryTable', headers, data_values)

    def __setStops__(self):
        current_row = self.stopSummaryTable.currentRow()
        current_item = self.stopSummaryTable.item(current_row, 0)
        stop_name = current_item.text()
        self.stopsSelected.emit(stop_name)

    def isStopSelected(self):
        return self.stopSummaryTable.isItemSelected()

    #####
    # General functions
    def __setTextField__(self, gui_name, text_list):
        field2 = self.findChild(QtGui.QTextEdit, gui_name)
        field2.clear()
        for line in text_list:
            field2.append(line)

    def __populateDataTable__(self, gui_name, headers, values):
        table = self.findChild(QtGui.QTableWidget, gui_name)
        table.clear()
        columns = len(headers)
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

    def __setSliderRange__(self, gui_name, minimum, maximum, step):
        slider = self.findChild(QtGui.QSlider, gui_name)
        slider.setRange(minimum, maximum)
        slider.setSingleStep(step)
