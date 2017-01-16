# -*- coding: utf-8 -*-
"""
/***************************************************************************
 KPOpilot
                                 A QGIS plugin
 Knooppunten Datasysteem
                             -------------------
        begin                : 2016-12-19
        copyright            : (C) 2016 by Jorge Gil
        email                : gil.jorge@gmail.com
        git sha              : $Format:%H$
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
 This script initializes the plugin, making it known to QGIS.
"""


# noinspection PyPep8Naming
def classFactory(iface):  # pylint: disable=invalid-name
    """Load KPOpilot class from file KPOpilot.

    :param iface: A QGIS interface instance.
    :type iface: QgsInterface
    """
    #
    from .kpo_datasysteem_pilot import KPOpilot
    return KPOpilot(iface)
