FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Build tools, Qt 5, and the libraries Player and Stage compile against.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        freeglut3-dev \
        libgdk-pixbuf-2.0-dev \
        libbluetooth-dev \
        libfltk1.3-dev \
        libfreetype6-dev \
        libgeos-dev \
        libgl1-mesa-dri \
        libglu1-mesa-dev \
        libjpeg-dev \
        libltdl-dev \
        libpng-dev \
        libqt5opengl5-dev \
        libtirpc-dev \
        libx11-xcb1 \
        libxcb-cursor0 \
        libxcb-glx0 \
        libxcb-icccm4 \
        libxcb-image0 \
        libxcb-keysyms1 \
        libxcb-randr0 \
        libxcb-render-util0 \
        libxcb-shape0 \
        libxcb-xfixes0 \
        libxcb-xinerama0 \
        libxcb-xkb1 \
        libxkbcommon-x11-0 \
        pkg-config \
        python3 \
        python3-lib2to3 \
        qtbase5-dev \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sfn /usr/include/tirpc/rpc /usr/include/rpc

COPY docker/build-player.sh docker/playerclient-mutex.patch /opt/casplanner-docker/
RUN chmod +x /opt/casplanner-docker/build-player.sh \
    && /opt/casplanner-docker/build-player.sh

WORKDIR /opt/casplanner
COPY . /opt/casplanner
RUN cmake -S /opt/casplanner -B /tmp/casplanner-build -DPLAYER_ROOT=/usr/local \
    && cmake --build /tmp/casplanner-build -j"$(nproc)"

ENV QT_QPA_PLATFORM=xcb \
    QT_X11_NO_MITSHM=1

CMD ["./CasPlanner", "wheelchair.cfg"]
