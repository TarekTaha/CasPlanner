#!/bin/bash
# Build Player 3.0.2 from source and install it under /usr/local.
set -euo pipefail

PLAYER_URL="https://github.com/playerproject/player/archive/refs/tags/release-3-0-2.tar.gz"
STAGE_URL="https://github.com/rtv/Stage/archive/refs/tags/v4.3.0.tar.gz"
SRC=/tmp/player-src
STAGE_SRC=/tmp/stage-src
JOBS="$(nproc)"

rm -rf "$SRC"
mkdir -p "$SRC"
curl -fsSL "$PLAYER_URL" | tar -xz -C "$SRC" --strip-components=1

cd "$SRC"

# CMake 3 still accepts the 2.4 requirement, but the generated install path
# uses lib64 on x86_64. Keep libraries on the normal lib directory.
sed -i 's/CMAKE_MINIMUM_REQUIRED (VERSION 2.4.7 FATAL_ERROR)/cmake_minimum_required(VERSION 3.5)/' CMakeLists.txt
sed -i 's/CMAKE_MINIMUM_REQUIRED (VERSION 2.6 FATAL_ERROR)/cmake_minimum_required(VERSION 3.5)/' CMakeLists.txt
sed -i 's/SET (PLAYER_LIBRARY_INSTALL_DIR "lib64")/SET (PLAYER_LIBRARY_INSTALL_DIR "lib")/' cmake/internal/SetupDirectories.cmake

# Modern GEOS ships only the C API library.
sed -i 's/PLAYERC_ADD_LINK_LIB (geos geos_c)/PLAYERC_ADD_LINK_LIB (geos_c)/' client_libs/libplayerc/CMakeLists.txt
sed -i 's/TARGET_LINK_LIBRARIES (playerwkb playercommon geos geos_c)/TARGET_LINK_LIBRARIES (playerwkb playercommon geos_c)/' libplayerwkb/CMakeLists.txt
sed -i 's/PLAYERCORE_ADD_INT_LINK_LIB (geos_c)/PLAYERCORE_ADD_INT_LINK_LIB (geos_c)/' libplayerwkb/CMakeLists.txt
sed -i 's/SET (wkbLibFlag "-lgeos -lgeos_c")/SET (wkbLibFlag "-lgeos_c")/' libplayerwkb/CMakeLists.txt

# Drop documentation, examples, and the optional GUI toolkit. Keep the Player
# server so `player` can load Stage and the drivers in StageSim/casarea.cfg.
sed -i '/ADD_SUBDIRECTORY (examples)/d; /ADD_SUBDIRECTORY (utils)/d; /ADD_SUBDIRECTORY (doc)/d; /ADD_SUBDIRECTORY (rtk2)/d' CMakeLists.txt

# Only the drivers that casarea.cfg names. The rest are hardware backends.
cat > server/drivers/CMakeLists.txt << 'EOF'
ADD_SUBDIRECTORY (localization)
ADD_SUBDIRECTORY (map)
ADD_SUBDIRECTORY (position)
ADD_SUBDIRECTORY (ranger)
EOF
cat > server/drivers/position/CMakeLists.txt << 'EOF'
ADD_SUBDIRECTORY (nd)
EOF

# gdk_pixbuf_get_n_channels() already counts the alpha channel. Adding it
# again reads past the end of the bitmap.
sed -i '/if(gdk_pixbuf_get_has_alpha(pixbuf))/,+1d' server/drivers/map/mapfile.cc
# Release builds define NDEBUG, which deletes assert() and the allocation
# hidden inside it. MapFile::Setup then writes through an uninitialized pointer.
python3 - << 'PY'
from pathlib import Path
path = Path("server/drivers/map/mapfile.cc")
text = path.read_text()
old = """  assert(this->mapdata = (char*)malloc(sizeof(char) *
                                       this->size_x * this->size_y));"""
new = """  this->mapdata = (char*)malloc(sizeof(char) * this->size_x * this->size_y);
  if (!this->mapdata)
  {
    PLAYER_ERROR("failed to allocate map");
    gdk_pixbuf_unref(pixbuf);
    return -1;
  }"""
if old not in text:
    raise SystemExit("map allocation assert was not found")
path.write_text(text.replace(old, new, 1))
PY

# Stage publishes range and intensity as separate ranger messages. An
# intensity-only laser packet has a zero range count, and libplayerc then
# writes the intensities through a zero-length buffer.
python3 - << 'PY'
from pathlib import Path
path = Path("server/drivers/ranger/rangertolaser.cc")
text = path.read_text()
old = "\tif (pose != NULL)\n\t\tPublish (device_addr, PLAYER_MSGTYPE_DATA, PLAYER_LASER_DATA_SCANPOSE,"
new = """\tif (rangeData == NULL)
\t{
\t\tdelete[] scanData.scan.ranges;
\t\tdelete[] scanData.scan.intensity;
\t\treturn 0;
\t}

\tif (pose != NULL)
\t\tPublish (device_addr, PLAYER_MSGTYPE_DATA, PLAYER_LASER_DATA_SCANPOSE,"""
if old not in text:
    raise SystemExit("rangertolaser publish site was not found")
path.write_text(text.replace(old, new, 1))
PY

# libc no longer provides XDR, so Player builds its own. The link line still
# pulls in the Windows sockets library whenever that happens.
sed -i '/TARGET_LINK_LIBRARIES (playerreplace Ws2_32)/d' replace/CMakeLists.txt
sed -i 's/\${ws2_32Lib}//g' replace/CMakeLists.txt

# The interface generators are Python 2. lib2to3 rewrites them in place, then
# the leftover string-module calls and string exceptions are rewritten by hand.
python3 -m lib2to3 -w -n libplayerinterface/playerinterfacegen.py libplayerinterface/playerxdrgen.py
python3 - << 'PY'
import re
from pathlib import Path
for path in [Path("libplayerinterface/playerinterfacegen.py"), Path("libplayerinterface/playerxdrgen.py")]:
    text = path.read_text()
    text = text.replace(
        "string.join(interface_filename.split(\"_\")[1:],'_')",
        "'_'.join(interface_filename.split(\"_\")[1:])",
    )
    text = text.replace("string.split(body)", "body.split()")
    text = re.sub(r"raise\s+('[^']*'|\"[^\"]*\")", r"raise RuntimeError(\1)", text)
    path.write_text(text)
import py_compile
py_compile.compile("libplayerinterface/playerinterfacegen.py", doraise=True)
py_compile.compile("libplayerinterface/playerxdrgen.py", doraise=True)
PY

python3 - << 'PY'
from pathlib import Path
path = Path("client_libs/libplayerc++/playerclient.h")
text = path.read_text()
old = """#else
  // we have to define this so we don't have to
  // comment out all the instances of scoped_lock
  // in all the proxies
  namespace boost
  {
    class PLAYERCC_EXPORT thread
    {
      public:
        thread() {};
    };

    class PLAYERCC_EXPORT mutex
    {
      public:
        mutex() {};
        class scoped_lock
        {
          public: scoped_lock(mutex /*m*/) {};
        };
    };
  }
"""
new = """#else
  // Boost.Thread is not part of this build. The same lock callsites are
  // backed by a pthread mutex.
  #include <pthread.h>
  namespace boost
  {
    class PLAYERCC_EXPORT thread
    {
      public:
        thread() {};
    };

    class PLAYERCC_EXPORT mutex
    {
      pthread_mutex_t m;
      public:
        mutex() { pthread_mutex_init(&m, 0); }
        ~mutex() { pthread_mutex_destroy(&m); }
        mutex(const mutex&) { pthread_mutex_init(&m, 0); }
        mutex& operator=(const mutex&) { return *this; }
        class scoped_lock
        {
          pthread_mutex_t* pm;
          public:
            scoped_lock(mutex& mu) : pm(&mu.m) { pthread_mutex_lock(pm); }
            ~scoped_lock() { pthread_mutex_unlock(pm); }
        };
        friend class scoped_lock;
    };
  }
"""
if old not in text:
    raise SystemExit("playerclient.h mutex stub was not found")
path.write_text(text.replace(old, new, 1))
PY

# rpc/types.h lives in libtirpc on current Debian and Ubuntu.
export CFLAGS="-fPIC -fcommon -I/usr/include/tirpc"
export CXXFLAGS="-fPIC -fcommon -std=gnu++14 -fpermissive -Wno-error -I/usr/include/tirpc"

cmake -S "$SRC" -B /tmp/player-build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_PLAYERCC_BOOST=OFF \
    -DPLAYER_BUILD_TESTS=OFF \
    -DCMAKE_C_FLAGS="$CFLAGS" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS"

cmake --build /tmp/player-build -j"$JOBS"
cmake --install /tmp/player-build
echo /usr/local/lib > /etc/ld.so.conf.d/player.conf
ldconfig

# Stage simulator, built against the Player we just installed.
rm -rf "$STAGE_SRC"
mkdir -p "$STAGE_SRC"
curl -fsSL "$STAGE_URL" | tar -xz -C "$STAGE_SRC" --strip-components=1
sed -i 's/cmake_minimum_required( VERSION 2.8.7 FATAL_ERROR )/cmake_minimum_required(VERSION 3.5)/' "$STAGE_SRC/CMakeLists.txt"
# The first GUI frame can draw a ranger before its range buffer exists.
python3 - << PY
from pathlib import Path
path = Path("$STAGE_SRC/libstage/model_ranger.cc")
text = path.read_text()
needle = "std::vector<glpoint_t> verts( sample_count );"
guard = """if (ranges.size() != sample_count) {
    glPopMatrix();
    return;
  }

  """
if needle not in text:
    raise SystemExit("ranger Visualize site was not found")
path.write_text(text.replace(needle, guard + needle, 1))
PY
# Fl::wait() with no timeout only watches the Stage window, so Player stops
# answering clients until an X event arrives.
sed -i 's/Fl::wait();/Fl::wait(0.05);/' "$STAGE_SRC/libstageplugin/p_driver.cc"
# Fl::lock() turns on FLTK's threaded mode. A driver thread that then enters
# Fl::wait()/Fl::check() returns still holding that lock, and the server
# thread blocks forever trying to take it back. Clients time out on every
# request. The GUI runs on the server thread, so the lock is unnecessary.
sed -i '/Fl::lock();/d' "$STAGE_SRC/libstage/worldgui.cc"
# Player's generated headers include <rpc/types.h>, which libtirpc keeps
# outside the default search path.
ln -sfn /usr/include/tirpc/rpc /usr/local/include/rpc
export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
cmake -S "$STAGE_SRC" -B /tmp/stage-build \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_PLAYER_PLUGIN=ON \
    -DCMAKE_C_FLAGS="-fPIC -I/usr/include/tirpc" \
    -DCMAKE_CXX_FLAGS="-fPIC -fpermissive -std=gnu++14 -Wno-error -I/usr/include/tirpc"
cmake --build /tmp/stage-build -j"$JOBS"
cmake --install /tmp/stage-build
ldconfig
