FROM centos:7

# Install yum pkg deps
RUN yum update -y \
      && yum install -y \
        curl \
        iproute \
        java-1.8.0-openjdk-headless \
        unzip \
        which \
      && yum clean all

# Add jq
RUN export JQ_VER=1.5 \
  && export JQ_URL=https://github.com/stedolan/jq/releases/download/jq-${JQ_VER}/jq-linux64 \
  && curl -Ls --fail -o /bin/jq ${JQ_URL} \
  && chmod +x /bin/jq

ENV JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk

# Add ElasticSearch and its configuration
ENV ES_HOME=/usr/share/elasticsearch
ENV PATH=${ES_HOME}/bin:$PATH
RUN export ES_VER=5.5.0 \
    && export ES_PKG=elasticsearch-${ES_VER}.tar.gz \
    && export ES_URL=https://artifacts.elastic.co/downloads/elasticsearch/${ES_PKG} \
    && export ES_SHA1=d79a3ade8b8589d13aeb99ceec1c54683596e88b \
    && curl -Ls --fail -o /tmp/${ES_PKG} ${ES_URL} \
    && echo "${ES_SHA1} /tmp/${ES_PKG}" | sha1sum -c \
    && tar zxf /tmp/${ES_PKG} -C /usr/share \
    && mv ${ES_HOME}-${ES_VER} ${ES_HOME} \
    && rm /tmp/${ES_PKG} \
    && ${ES_HOME}/bin/elasticsearch-plugin install x-pack \
    && groupadd -g 1000 elasticsearch \
    && adduser -u 1000 -g 1000 -d ${ES_HOME} elasticsearch \
    && mkdir -p /var/log/elasticsearch \
    && chown -R elasticsearch:elasticsearch /var/log/elasticsearch \
    && mkdir -p /var/lib/elasticsearch/data \
    && chown -R elasticsearch:elasticsearch /var/lib/elasticsearch/data \
    && chown -R elasticsearch:elasticsearch ${ES_HOME}/config \
    && chmod g+w ${ES_HOME}

# Add ContainerPilot and set its configuration
ENV CONTAINERPILOT=/etc/containerpilot.json5
RUN export CP_VER=3.3.0 \
    && export CP_PKG=containerpilot-${CP_VER}.tar.gz \
    && export CP_SHA1=62621712ef6ba755e24805f616096de13e2fd087 \
    && export CP_URL=https://github.com/joyent/containerpilot/releases/download/${CP_VER}/${CP_PKG} \
    && curl -Ls --fail -o /tmp/${CP_PKG} ${CP_URL} \
    && echo "${CP_SHA1} /tmp/${CP_PKG}" | sha1sum -c \
    && tar zxf /tmp/${CP_PKG} -C /usr/local/bin \
    && rm /tmp/${CP_PKG} \
    && mkdir -p /var/run/containerpilot \
    && chown elasticsearch:elasticsearch /var/run/containerpilot

# Add Consul and set its configuration
RUN export CONSUL_VER=0.9.0 \
    && export CONSUL_PKG=consul_${CONSUL_VER}_linux_amd64.zip \
    && export CONSUL_URL=https://releases.hashicorp.com/consul/${CONSUL_VER}/${CONSUL_PKG} \
    && export CONSUL_SHA1=345efaf9b055c92caf6221a5d58d84e96acddf24 \
    && curl -Ls --fail -o /tmp/${CONSUL_PKG} ${CONSUL_URL} \
    && echo "${CONSUL_SHA1} /tmp/${CONSUL_PKG}" | sha1sum -c \
    && unzip /tmp/${CONSUL_PKG} -d /usr/local/bin \
    && rm /tmp/${CONSUL_PKG} \
    && mkdir /data \
    && chown elasticsearch:elasticsearch /data \
    && mkdir /config \
    && chown elasticsearch:elasticsearch /config

# Copy Other Files into the Image.
COPY /bin/manage.sh /usr/local/bin
COPY /etc/elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml
COPY /etc/containerpilot.json5 /etc

# Expose the data directory as a volume in case we want to mount these
# as a --volumes-from target; it's important that this VOLUME comes
# after the creation of the directory so that we preserve ownership.
VOLUME /var/lib/elasticsearch/data

EXPOSE 9200
EXPOSE 9300

# Set the ES user
USER elasticsearch
