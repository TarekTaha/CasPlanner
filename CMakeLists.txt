cmake_minimum_required(VERSION 3.16)
project(CasPlanner C CXX)

# CasPlanner 1.0 was built against Qt 4, Player 3.0 and a 32-bit Pentium-M
# toolchain. This file keeps that same program, but builds it with Qt 5 and
# the host compiler. PLAYER_ROOT is a Player tree built from source
# (the Docker image installs one under /usr/local). If that is absent, the
# unpacked libraries in CASPLANNER_DEPS are used.
if(NOT CASPLANNER_DEPS)
    if(DEFINED ENV{CASPLANNER_DEPS})
        set(CASPLANNER_DEPS "$ENV{CASPLANNER_DEPS}" CACHE PATH "Directory holding unpacked build dependencies")
    else()
        set(CASPLANNER_DEPS "$ENV{HOME}/.local/casplanner-deps" CACHE PATH "Directory holding unpacked build dependencies")
    endif()
endif()
set(PLAYER_ROOT "" CACHE PATH "Prefix of a Player installation built from source")

if(PLAYER_ROOT AND EXISTS "${PLAYER_ROOT}/include/player-3.0/playerconfig.h")
    set(PLAYER_INCLUDE "${PLAYER_ROOT}/include/player-3.0")
    set(PLAYER_LIB_DIR "${PLAYER_ROOT}/lib")
elseif(EXISTS "/usr/local/include/player-3.0/playerconfig.h")
    set(PLAYER_INCLUDE "/usr/local/include/player-3.0")
    set(PLAYER_LIB_DIR "/usr/local/lib")
elseif(EXISTS "${CASPLANNER_DEPS}/player-cxx/include/libplayerc++/playerc++.h")
    set(PLAYER_INCLUDE "${CASPLANNER_DEPS}/player/usr/include/player-3.0")
    set(PLAYER_CXX_INCLUDE "${CASPLANNER_DEPS}/player-cxx/include")
    set(PLAYER_LIB_DIR "${CASPLANNER_DEPS}/player/usr/lib")
    set(PLAYER_CXX_LIB_DIR "${CASPLANNER_DEPS}/player-cxx/lib")
else()
    message(FATAL_ERROR "Player headers were not found. Set PLAYER_ROOT to a source install, or unpack Player into CASPLANNER_DEPS.")
endif()
if(NOT PLAYER_CXX_INCLUDE)
    set(PLAYER_CXX_INCLUDE "${PLAYER_INCLUDE}")
endif()
if(NOT PLAYER_CXX_LIB_DIR)
    set(PLAYER_CXX_LIB_DIR "${PLAYER_LIB_DIR}")
endif()

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOUIC_SEARCH_PATHS "${CMAKE_SOURCE_DIR}/gui")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}")

set(DEPS_LIB_DIR "${CASPLANNER_DEPS}/root/usr/lib/x86_64-linux-gnu")
set(DEPS_INCLUDE "${CASPLANNER_DEPS}/root/usr/include")
if(EXISTS "${CASPLANNER_DEPS}/root/usr")
    list(APPEND CMAKE_PREFIX_PATH "${CASPLANNER_DEPS}/root/usr")
endif()

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Gui Widgets OpenGL Xml)
find_package(OpenGL REQUIRED)
find_package(Freetype REQUIRED)

find_library(GLUT_LIBRARY glut PATHS "${DEPS_LIB_DIR}" REQUIRED)
find_library(GLU_LIBRARY GLU PATHS "${DEPS_LIB_DIR}" /usr/lib/x86_64-linux-gnu REQUIRED)
find_library(BLUETOOTH_LIBRARY bluetooth PATHS "${DEPS_LIB_DIR}" REQUIRED)

set(CASPLANNER_RPATH "${PLAYER_CXX_LIB_DIR};${PLAYER_LIB_DIR}")
if(EXISTS "${DEPS_LIB_DIR}")
    list(APPEND CASPLANNER_RPATH "${DEPS_LIB_DIR}")
endif()
set(CMAKE_BUILD_RPATH "${CASPLANNER_RPATH}")
set(CMAKE_INSTALL_RPATH "${CASPLANNER_RPATH}")
# RUNPATH applies only to CasPlanner itself. libplayerc then needs
# libplayerwkb and libplayerjpeg, so use DT_RPATH, which the loader also
# searches for those indirect libraries.
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--disable-new-dtags")

set(CasPlanner_SRCS
    ./modules/CommManager/commmanager.cpp
    ./modules/CommonTools/bandmat.cpp
    ./modules/CommonTools/cholesky.cpp
    ./modules/CommonTools/evalue.cpp
    ./modules/CommonTools/fft.cpp
    ./modules/CommonTools/hholder.cpp
    ./modules/CommonTools/jacobi.cpp
    ./modules/CommonTools/myexcept.cpp
    ./modules/CommonTools/newfft.cpp
    ./modules/CommonTools/newmat1.cpp
    ./modules/CommonTools/newmat2.cpp
    ./modules/CommonTools/newmat3.cpp
    ./modules/CommonTools/newmat4.cpp
    ./modules/CommonTools/newmat5.cpp
    ./modules/CommonTools/newmat6.cpp
    ./modules/CommonTools/newmat7.cpp
    ./modules/CommonTools/newmat8.cpp
    ./modules/CommonTools/newmat9.cpp
    ./modules/CommonTools/newmatex.cpp
    ./modules/CommonTools/newmatnl.cpp
    ./modules/CommonTools/newmatrm.cpp
    ./modules/CommonTools/nm_misc.cpp
    ./modules/CommonTools/solution.cpp
    ./modules/CommonTools/sort.cpp
    ./modules/CommonTools/submat.cpp
    ./modules/CommonTools/svd.cpp
    ./modules/Rendering/laserrender.cpp
    ./modules/Logger/logger.cpp
    ./modules/Parser/configfile.cc
    ./modules/Navigator/controller.cpp
    ./gui/planningsettings.cpp
    ./gui/missioncontroltab.cpp
    ./gui/loggerview.cpp
    ./gui/hritab.cpp
    ./gui/main.cpp
    ./gui/mainwindow.cpp
    ./gui/playgroundtab.cpp
    ./gui/statusbar.cpp
    ./gui/tabcontainer.cpp
    ./modules/Rendering/mapviewer.cpp
    ./modules/MapManager/mapmanager.cpp
    ./modules/Navigator/navigator.cpp
    ./modules/Rendering/ogrender.cpp
    ./modules/CommManager/playerinterface.cpp
    ./modules/Parser/xmlparser.cpp
    ./modules/Parser/settings.cpp
    ./modules/PathPlanner/planningmanager.cpp
    ./modules/PlayGround/playground.cpp
    ./modules/PlayGround/robotmanager.cpp
    ./modules/Rendering/robotrender.cpp
    ./modules/Sensors/sensors.cpp
    ./modules/TasksManager/task.cpp
    ./modules/TasksManager/tasksgui.cpp
    ./modules/Rendering/speedrender.cpp
    ./modules/PathPlanner/astar.cpp
    ./modules/ObstacleAvoidance/forcefield.cpp
    ./modules/ScanMatching/geometry2D.cpp
    ./modules/ScanMatching/icp.cpp
    ./modules/ScanMatching/nn.cpp
    ./modules/PathPlanner/llist.cpp
    ./modules/PathPlanner/node.cpp
    ./modules/PathPlanner/pathplanner.cpp
    ./modules/PathPlanner/robot.cpp
    ./modules/PathPlanner/searchspace.cpp
    ./modules/PathPlanner/searchspacenode.cpp
    ./modules/PathPlanner/voronoipathplanner.cpp
    ./modules/Misc/timer.cpp
    ./modules/GeometricTools/Vector2d.cpp
    ./modules/PomdpCore/CassandraModel.cc
    ./modules/PomdpCore/CassandraParser.cc
    ./modules/PomdpCore/decision-tree.c
    ./modules/PomdpCore/imm-reward.c
    ./modules/PomdpCore/mdp.c
    ./modules/PomdpCore/Pomdp.cc
    ./modules/PomdpCore/sparse-matrix.c
    ./modules/PomdpCore/zmdpCommonTime.cc
    ./modules/PomdpCore/zmdpCommonTypes.cc
    ./modules/PomdpCore/zmdpConfig.cc
    ./modules/PomdpCore/pomdp_spec.tab.cc
    ./modules/PomdpCore/pomdp_spec.yy.cc
    ./modules/PomdpCore/parse_err.c
    ./modules/PomdpCore/parse_hash.c
    ./modules/PomdpCore/BoundPairExec.cc
    ./modules/PomdpCore/MDPExec.cc
    ./modules/PomdpCore/MaxPlanesLowerBound.cc
    ./modules/PomdpCore/BoundPairCore.cc
    ./modules/PomdpCore/BoundPair.cc
    ./modules/PomdpCore/MDPCache.cc
    ./modules/PomdpCore/BlindLBInitializer.cc
    ./modules/MapManager/mapskeleton.cpp
    ./modules/MapManager/map.cpp
    ./modules/HumanRobotInteraction/IntentionRecognizer.cpp
    ./modules/HumanRobotInteraction/activityLogger.cpp
    ./modules/Controller/wheelchairproxy.cpp
    ./modules/Rendering/FreeType.cpp
    ./modules/CommManager/accelerometer.cpp
    ./modules/PathPlanner/socialplanner.cpp
    ./modules/ExceptionHandling/casplannerexception.cpp
    ./modules/PathPlanner/heuristic.cpp
)

set(CasPlanner_UIS
    gui/hritab.ui
    gui/loggerview.ui
    gui/configparsertab.ui
    gui/missioncontroltab.ui
    gui/planningsettings.ui
)

# Headers that declare Q_OBJECT. Listing them makes moc see classes that
# are only included indirectly from the .cpp files.
set(CasPlanner_MOC_HDRS
    ./modules/CommManager/commmanager.h
    ./modules/CommManager/comms.h
    ./modules/Rendering/glrender.h
    ./modules/Rendering/laserrender.h
    ./gui/planningsettings.h
    ./gui/missioncontroltab.h
    ./gui/hritab.h
    ./gui/mainwindow.h
    ./gui/playgroundtab.h
    ./gui/statusbar.h
    ./gui/tabcontainer.h
    ./gui/loggerview.h
    ./modules/Logger/logger.h
    ./modules/Parser/settings.h
    ./modules/Rendering/mapviewer.h
    ./modules/Navigator/navigator.h
    ./modules/Rendering/ogrender.h
    ./modules/CommManager/playerinterface.h
    ./modules/Parser/xmlparser.h
    ./modules/PathPlanner/planningmanager.h
    ./modules/PlayGround/playground.h
    ./modules/PlayGround/robotmanager.h
    ./modules/Rendering/robotrender.h
    ./modules/Sensors/sensors.h
    ./modules/TasksManager/tasksgui.h
    ./modules/HumanRobotInteraction/IntentionRecognizer.h
)

add_executable(CasPlanner
    ${CasPlanner_SRCS}
    ${CasPlanner_MOC_HDRS}
    ${CasPlanner_UIS}
    resources/icons.qrc
)

target_compile_options(CasPlanner PRIVATE
    -Wall
    -Wno-deprecated
    -Wno-deprecated-declarations
    -Wno-register
    -Wno-unused-parameter
    -fmessage-length=0
    -fpermissive
    -ffast-math
    -fcommon
)

# QT_NO_KEYWORDS keeps the original Q_SIGNALS / Q_SLOTS style working
# alongside identifiers that would otherwise collide with Qt macros.
target_compile_definitions(CasPlanner PRIVATE QT_NO_KEYWORDS QT_NO_DEBUG)

set(CASPLANNER_EXTRA_INCLUDES)
if(EXISTS "/usr/include/tirpc/rpc/types.h")
    list(APPEND CASPLANNER_EXTRA_INCLUDES /usr/include/tirpc)
endif()
if(EXISTS "${DEPS_INCLUDE}")
    list(APPEND CASPLANNER_EXTRA_INCLUDES "${DEPS_INCLUDE}" "${DEPS_INCLUDE}/freetype2" "${DEPS_INCLUDE}/tirpc")
endif()

target_include_directories(CasPlanner PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}
    ${PLAYER_CXX_INCLUDE}
    ${PLAYER_INCLUDE}
    ${CASPLANNER_EXTRA_INCLUDES}
    ${FREETYPE_INCLUDE_DIRS}
    ./modules/Logger
    ./modules/PathPlanner
    ./modules/ObstacleAvoidance
    ./modules/ScanMatching
    ./modules/Misc
    ./modules/GeometricTools
    ./modules/Controller
    ./modules/CommManager
    ./modules/CommonTools
    ./modules/MapManager
    ./modules/Navigator
    ./modules/Parser
    ./modules/PlanningManager
    ./modules/PlayGround
    ./modules/Rendering
    ./modules/Sensors
    ./modules/TasksManager
    ./modules/ExceptionHandling
    ./gui
    ./modules/PomdpCore
    ./modules/HumanRobotInteraction
)

target_link_directories(CasPlanner PRIVATE
    ${PLAYER_CXX_LIB_DIR}
    ${PLAYER_LIB_DIR}
    ${DEPS_LIB_DIR}
)

target_link_libraries(CasPlanner PRIVATE
    Qt5::Core
    Qt5::Gui
    Qt5::Widgets
    Qt5::OpenGL
    Qt5::Xml
    OpenGL::GL
    ${GLU_LIBRARY}
    ${GLUT_LIBRARY}
    ${FREETYPE_LIBRARIES}
    ${BLUETOOTH_LIBRARY}
    playerc++
    playerc
    playerinterface
    playercommon
    playerwkb
    playerjpeg
    m
    pthread
)
