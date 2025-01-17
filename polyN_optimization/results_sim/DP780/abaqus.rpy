# -*- coding: mbcs -*-
#
# Abaqus/Viewer Release 2023 replay file
# Internal Version: 2022_09_28-20.11.55 183150
# Run by cnober on Fri Jun 21 17:04:11 2024
#

# from driverUtils import executeOnCaeGraphicsStartup
# executeOnCaeGraphicsStartup()
#: Executing "onCaeGraphicsStartup()" in the site directory ...
from abaqus import *
from abaqusConstants import *
session.Viewport(name='Viewport: 1', origin=(0.0, 0.0), width=297.310424804688, 
    height=142.020004272461)
session.viewports['Viewport: 1'].makeCurrent()
session.viewports['Viewport: 1'].maximize()
from viewerModules import *
from driverUtils import executeOnCaeStartup
executeOnCaeStartup()
o2 = session.openOdb(name='CH_00_UMAT_1_2.odb')
#: Model: C:/temp/polyN_optimization/results_sim/DP780/CH_00_UMAT_1_2.odb
#: Number of Assemblies:         1
#: Number of Assembly instances: 0
#: Number of Part instances:     1
#: Number of Meshes:             1
#: Number of Element Sets:       9
#: Number of Node Sets:          10
#: Number of Steps:              1
session.viewports['Viewport: 1'].setValues(displayedObject=o2)
session.viewports['Viewport: 1'].makeCurrent()
session.viewports['Viewport: 1'].animationController.setValues(
    animationType=TIME_HISTORY)
session.viewports['Viewport: 1'].animationController.play(duration=UNLIMITED)
odb = session.odbs['C:/temp/polyN_optimization/results_sim/DP780/CH_00_UMAT_1_2.odb']
xy1 = xyPlot.XYDataFromHistory(odb=odb, 
    outputVariableName='Stress components: S11 at Element 11993 Int Point 1 in ELSET ONSET', 
    steps=('Step-1', ), suppressQuery=True, __linkedVpName__='Viewport: 1')
c1 = session.Curve(xyData=xy1)
xy2 = xyPlot.XYDataFromHistory(odb=odb, 
    outputVariableName='Stress components: S12 at Element 11993 Int Point 1 in ELSET ONSET', 
    steps=('Step-1', ), suppressQuery=True, __linkedVpName__='Viewport: 1')
c2 = session.Curve(xyData=xy2)
xy3 = xyPlot.XYDataFromHistory(odb=odb, 
    outputVariableName='Stress components: S13 at Element 11993 Int Point 1 in ELSET ONSET', 
    steps=('Step-1', ), suppressQuery=True, __linkedVpName__='Viewport: 1')
c3 = session.Curve(xyData=xy3)
xy4 = xyPlot.XYDataFromHistory(odb=odb, 
    outputVariableName='Stress components: S22 at Element 11993 Int Point 1 in ELSET ONSET', 
    steps=('Step-1', ), suppressQuery=True, __linkedVpName__='Viewport: 1')
c4 = session.Curve(xyData=xy4)
xy5 = xyPlot.XYDataFromHistory(odb=odb, 
    outputVariableName='Stress components: S23 at Element 11993 Int Point 1 in ELSET ONSET', 
    steps=('Step-1', ), suppressQuery=True, __linkedVpName__='Viewport: 1')
c5 = session.Curve(xyData=xy5)
xy6 = xyPlot.XYDataFromHistory(odb=odb, 
    outputVariableName='Stress components: S33 at Element 11993 Int Point 1 in ELSET ONSET', 
    steps=('Step-1', ), suppressQuery=True, __linkedVpName__='Viewport: 1')
c6 = session.Curve(xyData=xy6)
xyp = session.XYPlot('XYPlot-1')
chartName = xyp.charts.keys()[0]
chart = xyp.charts[chartName]
chart.setValues(curvesToPlot=(c1, c2, c3, c4, c5, c6, ), )
session.charts[chartName].autoColor(lines=True, symbols=True)
session.viewports['Viewport: 1'].setValues(displayedObject=xyp)
