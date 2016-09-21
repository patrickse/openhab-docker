# openhab image 
FROM multiarch/ubuntu-debootstrap:amd64-wily
#FROM multiarch/ubuntu-debootstrap:armhf-wily   # arch=armhf
#FROM multiarch/ubuntu-debootstrap:arm64-wily   # arch=arm64
ARG ARCH=amd64

ARG ZULU_SHA=66faeba9f310cb2cbfa783dea38251b0a57509d8d297d46ffa7a6d18f764dcff
ARG ZULU_DOWNLOAD_URL=http://cdn.azul.com/zulu/bin/zulu8.14.0.1-jdk8.0.91-linux_x64.tar.gz 

#ARG ZULU_SHA=ad204157dd34fe95c8dd3a0b83b6b1a3327019b90d2c14f33bd151917a5ad78a                           #arch=armhf
#ARG ZULU_DOWNLOAD_URL=http://cdn.azul.com/zulu-embedded/bin/ezdk-1.8.0_91-8.14.0.6-linux_aarch32.tar.gz #arch=armhf
ARG ZULU_INSTALL_DIR=/usr/lib/jvm

ARG DOWNLOAD_URL="https://openhab.ci.cloudbees.com/job/openHAB-Distribution/lastSuccessfulBuild/artifact/distributions/openhab-online/target/openhab-online-2.0.0-SNAPSHOT.zip"
ENV APPDIR="/openhab" OPENHAB_HTTP_PORT='8080' OPENHAB_HTTPS_PORT='8443' EXTRA_JAVA_OPTS=''

# Basic build-time metadata as defined at http://label-schema.org
ARG BUILD_DATE
ARG VCS_REF
LABEL org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.docker.dockerfile="/Dockerfile" \
    org.label-schema.license="EPL" \
    org.label-schema.name="openHAB" \
    org.label-schema.url="http://www.openhab.com/" \
    org.label-schema.vcs-ref=$VCS_REF \
    org.label-schema.vcs-type="Git" \
    org.label-schema.vcs-url="https://github.com/openhab/openhab-docker.git"

# Install Basepackages
RUN \
    apt-get update && \
    apt-get install --no-install-recommends -y \
      sudo \
      unzip \
      wget \
    && rm -rf /var/lib/apt/lists/*

# Install Zulu OpenJDK
RUN \
   wget -nv -O /tmp/zulu.tar.gz $ZULU_DOWNLOAD_URL \
    && mkdir -p $ZULU_INSTALL_DIR
RUN \
    tar xzf /tmp/zulu.tar.gz -C ${ZULU_INSTALL_DIR} \
    && rm /tmp/zulu.tar.gz \
    && JAVA_NAME=`ls -t $ZULU_INSTALL_DIR | head -1` \
    && ln -s $ZULU_INSTALL_DIR/$JAVA_NAME $ZULU_INSTALL_DIR/java
ENV JAVA_HOME=$ZULU_INSTALL_DIR/java
ENV PATH=$PATH:$JAVA_HOME/bin

# Add openhab user & handle possible device groups for different host systems
# Container base image puts dialout on group id 20, uucp on id 10
RUN adduser --disabled-password --gecos '' --home ${APPDIR} openhab &&\
    adduser openhab sudo &&\
    groupadd -g 14 uucp2 &&\
    groupadd -g 16 dialout2 &&\
    groupadd -g 18 dialout3 &&\
    groupadd -g 32 uucp3 &&\
    adduser openhab dialout &&\
    adduser openhab uucp &&\
    adduser openhab uucp2 &&\
    adduser openhab dialout2 &&\
    adduser openhab dialout3 &&\
    adduser openhab uucp3 &&\
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/openhab

WORKDIR ${APPDIR}

RUN \
    wget -nv -O /tmp/openhab.zip ${DOWNLOAD_URL} &&\
    unzip -q /tmp/openhab.zip -d ${APPDIR} &&\
    rm /tmp/openhab.zip

RUN mkdir -p ${APPDIR}/userdata/logs && touch ${APPDIR}/userdata/logs/openhab.log

# Copy directories for host volumes
RUN cp -a /openhab/userdata /openhab/userdata.dist && \
    cp -a /openhab/conf /openhab/conf.dist
COPY files/entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

RUN chown -R openhab:openhab ${APPDIR}

USER openhab
# Expose volume with configuration and userdata dir
VOLUME ${APPDIR}/conf ${APPDIR}/userdata ${APPDIR}/addons
EXPOSE 8080 8443 5555
CMD ["server"]
