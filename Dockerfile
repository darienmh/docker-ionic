FROM ubuntu:18.04
MAINTAINER Juan Darien Macías Hernández <darienmh@gmail.com>

# -----------------------------------------------------------------------------
# General environment variables
# -----------------------------------------------------------------------------
ENV DEBIAN_FRONTEND=noninteractive

ARG CORDOVA_ANDROID_GRADLE_DISTRIBUTION_URL
ENV CORDOVA_ANDROID_GRADLE_DISTRIBUTION_URL ${CORDOVA_ANDROID_GRADLE_DISTRIBUTION_URL:-https://downloads.gradle.org/distributions/gradle-4.1-all.zip}
RUN echo ${CORDOVA_ANDROID_GRADLE_DISTRIBUTION_URL}


# -----------------------------------------------------------------------------
# Install system basics
# -----------------------------------------------------------------------------
RUN \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated \
          apt-transport-https \
          #python-software-properties \
          software-properties-common \
          curl \
          expect \ 
          zip \
          libsass-dev \
          git \
          sudo


# -----------------------------------------------------------------------------
# Install Java
# -----------------------------------------------------------------------------
ARG JAVA_VERSION
ENV JAVA_VERSION ${JAVA_VERSION:-8}

ENV JAVA_HOME ${JAVA_HOME:-/usr/lib/jvm/java-${JAVA_VERSION}-oracle}

RUN \
  add-apt-repository ppa:webupd8team/java -y && \
  echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | \
  /usr/bin/debconf-set-selections && \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated oracle-java${JAVA_VERSION}-installer


# -----------------------------------------------------------------------------
# Install Android / Android SDK / Android SDK elements
# -----------------------------------------------------------------------------

ENV ANDROID_HOME /opt/android-sdk-linux
ENV PATH ${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools:/opt/tools

ARG ANDROID_PLATFORMS_VERSION
ENV ANDROID_PLATFORMS_VERSION ${ANDROID_PLATFORMS_VERSION:-25}

ARG ANDROID_BUILD_TOOLS_VERSION
ENV ANDROID_BUILD_TOOLS_VERSION ${ANDROID_BUILD_TOOLS_VERSION:-25.0.3}

RUN \
  echo ANDROID_HOME=${ANDROID_HOME} >> /etc/environment && \
  dpkg --add-architecture i386 && \
  apt-get update -qqy && \
  apt-get install -qqy --allow-unauthenticated\
          gradle  \
          libc6-i386 \
          lib32stdc++6 \
          lib32gcc1 \
          lib32ncurses5 \
          lib32z1 \
          qemu-kvm \
          kmod && \
  cd /opt && \
  mkdir android-sdk-linux && \
  cd android-sdk-linux && \
  curl -SLo sdk-tools-linux.zip https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip && \
  unzip sdk-tools-linux.zip && \
  rm -f sdk-tools-linux.zip && \
  chmod 777 ${ANDROID_HOME} -R  && \
  mkdir -p ${ANDROID_HOME}/licenses && \
  echo 8933bad161af4178b1185d1a37fbf41ea5269c55 > ${ANDROID_HOME}/licenses/android-sdk-license && \
  sdkmanager "tools" && \  
  sdkmanager "platform-tools" && \
  sdkmanager "platforms;android-${ANDROID_PLATFORMS_VERSION}" && \
  sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}"


# -----------------------------------------------------------------------------
# Install Node, NPM, yarn
# -----------------------------------------------------------------------------
ARG NODE_VERSION
ENV NODE_VERSION ${NODE_VERSION:-8.11.2} 

ARG NPM_VERSION
ENV NPM_VERSION ${NPM_VERSION:-5.6.0}

ARG PACKAGE_MANAGER
ENV PACKAGE_MANAGER ${PACKAGE_MANAGER:-npm}

ENV NPM_CONFIG_LOGLEVEL info

# gpg keys listed at https://github.com/nodejs/node
RUN \
  curl -SLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz" && \
  tar -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz" -C /usr/local --strip-components=1 && \
  rm "node-v${NODE_VERSION}-linux-x64.tar.xz" && \
  ln -s /usr/local/bin/node /usr/local/bin/nodejs && \
  chmod 777 /usr/local/lib/node_modules -R
  #npm install -g npm@${NPM_VERSION} && \
  #if [ "${PACKAGE_MANAGER}" = "yarn" ]; then \
  #  curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
  #  echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list && \
  #  apt-get update -qqy && apt-get install -qqy --allow-unauthenticated yarn; \
  #fi


# -----------------------------------------------------------------------------
# Clean up
# -----------------------------------------------------------------------------
RUN \
  apt-get clean && \
  apt-get autoclean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 


# -----------------------------------------------------------------------------
# Create a non-root docker user to run this container
# -----------------------------------------------------------------------------
ARG USER
ENV USER ${USER:-ionic}

RUN \
  # create user with appropriate rights, groups and permissions
  useradd --user-group --create-home --shell /bin/false ${USER} && \
  echo "${USER}:${USER}" | chpasswd && \
  adduser ${USER} sudo && \
  adduser ${USER} root && \
  chmod 770 / && \
  usermod -a -G root ${USER} && \

  # create the file and set permissions now with root user  
  mkdir /app && chown ${USER}:${USER} /app && chmod 777 /app && \

  # create the file and set permissions now with root user
  touch /image.config && chown ${USER}:${USER} /image.config && chmod 777 /image.config && \

  # this is necessary for ionic commands to run
  mkdir /home/${USER}/.ionic && chown ${USER}:${USER} /home/${USER}/.ionic && chmod 777 /home/${USER}/.ionic && \

  # this is necessary to install global npm modules
  chmod 777 /usr/local/bin
  #&& chown ${USER}:${USER} ${ANDROID_HOME} -R


# -----------------------------------------------------------------------------
# Copy start.sh and set permissions 
# -----------------------------------------------------------------------------
COPY start.sh /start.sh
RUN chown ${USER}:${USER} /start.sh && chmod 777 /start.sh


# -----------------------------------------------------------------------------
# Switch the user of this image only now, because previous commands need to be 
# run as root
# -----------------------------------------------------------------------------
USER ${USER}


# -----------------------------------------------------------------------------
# Install Global node modules
# -----------------------------------------------------------------------------

ARG CORDOVA_VERSION
ENV CORDOVA_VERSION ${CORDOVA_VERSION:-8.0.0}

ARG IONIC_VERSION
ENV IONIC_VERSION ${IONIC_VERSION:-3.20.0}

ARG TYPESCRIPT_VERSION
ENV TYPESCRIPT_VERSION ${TYPESCRIPT_VERSION:-2.3.4}

ARG GULP_VERSION
ENV GULP_VERSION ${GULP_VERSION}

RUN \
  if [ "${PACKAGE_MANAGER}" != "yarn" ]; then \
    export PACKAGE_MANAGER="npm" && \
    npm install -g cordova@"${CORDOVA_VERSION}" && \
    if [ -n "${IONIC_VERSION}" ]; then npm install -g ionic@"${IONIC_VERSION}"; fi && \
    if [ -n "${TYPESCRIPT_VERSION}" ]; then npm install -g typescript@"${TYPESCRIPT_VERSION}"; fi && \
    if [ -n "${GULP_VERSION}" ]; then npm install -g gulp@"${GULP_VERSION}"; fi \
  else \
    yarn global add cordova@"${CORDOVA_VERSION}" && \
    if [ -n "${IONIC_VERSION}" ]; then yarn global add ionic@"${IONIC_VERSION}"; fi && \
    if [ -n "${TYPESCRIPT_VERSION}" ]; then yarn global add typescript@"${TYPESCRIPT_VERSION}"; fi && \
    if [ -n "${GULP_VERSION}" ]; then yarn global add gulp@"${GULP_VERSION}"; fi \
  fi && \
  ${PACKAGE_MANAGER} cache clean --force


# -----------------------------------------------------------------------------
# Create the image.config file for the container to check the build 
# configuration of this container later on 
# -----------------------------------------------------------------------------
RUN \
echo "USER: ${USER}\n\
JAVA_VERSION: ${JAVA_VERSION}\n\
ANDROID_PLATFORMS_VERSION: ${ANDROID_PLATFORMS_VERSION}\n\
ANDROID_BUILD_TOOLS_VERSION: ${ANDROID_BUILD_TOOLS_VERSION}\n\
NODE_VERSION: ${NODE_VERSION}\n\
NPM_VERSION: ${NPM_VERSION}\n\
PACKAGE_MANAGER: ${PACKAGE_MANAGER}\n\
CORDOVA_VERSION: ${CORDOVA_VERSION}\n\
IONIC_VERSION: ${IONIC_VERSION}\n\
TYPESCRIPT_VERSION: ${TYPESCRIPT_VERSION}\n\
GULP_VERSION: ${GULP_VERSION:-none}\n\
" >> /image.config && \
cat /image.config


# -----------------------------------------------------------------------------
# Generate an Ionic default app (do this with root user, since we will not
# have permissions for /app otherwise), install the dependencies
# and add and build android platform
# -----------------------------------------------------------------------------
#RUN \
  #cd / && \
  #ionic config set -g backend legacy && \
  #ionic start app blank --type ionic-angular --no-deps --no-link --no-git && \
  #write y

RUN \
  cd /app/ && \
  curl -SLO "https://d2ql0qc7j8u4b2.cloudfront.net/ionic-angular-official-super.tar.gz" && \
  tar -xzvf "ionic-angular-official-super.tar.gz" && \
  rm "ionic-angular-official-super.tar.gz" && \
  npm install && \
  ionic cordova platform add android && \
  ionic cordova platform add ios && \
  ionic cordova platform add windows && \
  ionic cordova platform add browser 


# -----------------------------------------------------------------------------
# Just in case you are installing from private git repositories, enable git
# credentials
# -----------------------------------------------------------------------------
RUN git config --global credential.helper store


# -----------------------------------------------------------------------------
# WORKDIR is the generic /app folder. All volume mounts of the actual project
# code need to be put into /app.
# -----------------------------------------------------------------------------
WORKDIR /app


# -----------------------------------------------------------------------------
# The script start.sh installs package.json and puts a watch on it. This makes
# sure that the project has allways the latest dependencies installed.
# -----------------------------------------------------------------------------
ENTRYPOINT ["/start.sh"]


# -----------------------------------------------------------------------------
# After /start.sh the bash is called.
# -----------------------------------------------------------------------------
#CMD ["ionic", "serve", "-b", "-p", "8100"]
