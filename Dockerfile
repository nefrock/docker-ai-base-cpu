FROM ubuntu:16.04
MAINTAINER ttsurumi@nefrock.com

# https://github.com/BVLC/caffe/wiki/Ubuntu-16.04-or-15.10-Installation-Guide#the-gpu-support-prerequisites
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    zip \
    wget \
    curl \
    ffmpeg \
    pkg-config \
    qtbase5-dev \
    libatlas-base-dev \
    libboost-all-dev \
    libgflags-dev \
    libgoogle-glog-dev \
    libhdf5-serial-dev \
    libleveldb-dev \
    liblmdb-dev \
    libopencv-dev \
    libprotobuf-dev \
    libsnappy-dev \
    protobuf-compiler \
    python-dev \
    python-scipy \
    python-numpy \
    python-tk \
    python3-dev \
    python3-scipy \
    python3-numpy \
    python3-tk\
    python-pip \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get install -y \
    gfortran \
    libatlas-dev \
    libavcodec-dev \
    libavformat-dev \
    libboost-all-dev \
    libgtk2.0-dev \
    libjpeg-dev \
    libswscale-dev \
    pkg-config \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# https://github.com/BVLC/caffe/wiki/OpenCV-3.1-Installation-Guide-on-Ubuntu-16.04
RUN apt-get install --assume-yes \
    libdc1394-22 \
    libdc1394-22-dev \
    libpng12-dev \
    libtiff5-dev \
    libjasper-dev

WORKDIR /workspace

# install opencv
RUN cd ~ && \
    mkdir -p ocv-tmp && \
    cd ocv-tmp && \
    curl -L https://github.com/opencv/opencv/archive/3.2.0.tar.gz -o ocv.tgz && \
    tar -zxvf ocv.tgz && \
    cd opencv-3.2.0 && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=RELEASE \
          -D CMAKE_INSTALL_PREFIX=/usr/local \
          -D BUILD_PYTHON_SUPPORT=ON \
          -D WITH_TBB=ON \
          -D WITH_V4L=ON \
          -D WITH_QT=ON \
          -D WITH_OPENGL=ON \
          .. && \
    make -j8 && \
    make install && \
    /bin/bash -c 'echo "/usr/local/lib" > /etc/ld.so.conf.d/opencv.conf' && \
    ldconfig && \
    apt-get update && \
    rm -rf ~/ocv-tmp

ENV CAFFE_ROOT=/opt/caffe
WORKDIR $CAFFE_ROOT

# FIXME: clone a specific git tag and use ARG instead of ENV once DockerHub supports this.
ENV CLONE_TAG=master

RUN git clone -b ${CLONE_TAG} --depth 1 https://github.com/BVLC/caffe.git . && \
    for req in $(cat python/requirements.txt) pydot; do pip install $req; done

COPY caffeconf/Makefile /opt/caffe/
COPY caffeconf/Makefile.config /opt/caffe/

RUN make all -j"$(nproc)" && \
    make test -j"$(nproc)" && \
    make runtest -j"$(nproc)" && \
    make pycaffe -j"$(nproc)" && \
    make distribute

ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

# install dlib
RUN cd ~ && \
    mkdir -p dlib-tmp && \
    cd dlib-tmp && \
    curl -L \
         https://github.com/davisking/dlib/archive/v19.2.tar.gz -o dlib.tar.gz && \
    tar zxvf dlib.tar.gz && \
    cd dlib-19.2/examples && \
    mkdir build && \
    cd build && \
    cmake .. && \
    cmake --build .  && \
    cd ../../ && \
    python setup.py install

RUN apt-get install -y libopenblas-dev swig
# install faiss
WORKDIR /root
RUN git clone https://github.com/facebookresearch/faiss.git
COPY faiss/makefile.inc /tmp
RUN cp /tmp/makefile.inc ~/faiss/ && \
    cd faiss && \
    make tests/test_blas -j $(nproc) && \
    make -j $(nproc) && \
    make tests/demo_sift1M -j $(nproc) && \
    make py
