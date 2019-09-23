FROM alexiri/scipy:latest as build_env

ENV FAVA_VERSION "master"
ENV FINGERPRINT "sha256:32:12:90:9a:70:64:82:1c:5b:52:cc:c3:0a:d0:79:db:e1:a8:62:1b:9a:9a:4c:f4:72:40:1c:a7:3a:d3:0a:8c"
ENV BUILDDEPS "libxml2-dev libxslt-dev gcc musl-dev mercurial git nodejs make g++ lapack-dev gfortran"
# Short python version.
ENV PV "3.6"

WORKDIR /root
RUN apk add --update ${BUILDDEPS} \
        && pip install --upgrade pip \
	&& python3 -mpip install importlib_metadata

RUN echo "Install Beancount & Fava" \
        && hg clone --config hostsecurity.bitbucket.org:fingerprints=$FINGERPRINT https://bitbucket.org/blais/beancount \
        && (cd beancount && hg log -l1) \
        && git clone --branch ${FAVA_VERSION} --depth 1 https://github.com/beancount/fava.git \
        && (cd fava && git log -1) \
        && echo "Deleting symlink files as they will cause docker build error" \
        && find ./ -type l -delete -print \
        && python3 -mpip install ./beancount \
        && make -C fava \
        && make -C fava mostlyclean \
        && python3 -mpip install ./fava

RUN echo "Install Smart Importer" \
        && git clone https://github.com/beancount/smart_importer.git \
        && (cd smart_importer && git log -1) \
        && python3 -mpip install ./smart_importer \
        && python3 -mpip install beancount_portfolio_allocation # \
        && echo "strip .so files:" \
        && find /usr/local/lib/python${PV}/site-packages -name *.so -print0|xargs -0 strip -v \
        && echo "remove __pycache__ directories" \
        && find /usr/local/lib/python${PV} -name __pycache__ -exec rm -rf -v {} + \
        && find /usr/local/lib/python${PV} -name '*.dist-info' -exec rm -rf -v {} +


FROM tiangolo/uwsgi-nginx-flask:python3.6-alpine3.7

ENV BEANCOUNT_INPUT_FILE "/data/example.beancount"
ENV PV "3.6"

RUN rm -f /app/*
VOLUME /data

RUN apk add --no-cache lapack libstdc++
COPY --from=build_env /usr/local/lib/python${PV}/site-packages /usr/local/lib/python${PV}/site-packages
COPY --from=build_env /usr/local/bin/fava /usr/local/bin
COPY --from=build_env /usr/local/bin/bean* /usr/local/bin/
ADD amortize_over.py /usr/local/lib/python${PV}/site-packages
RUN cp -r /usr/local/lib/python${PV}/site-packages/fava/static /app

COPY main.py /app
COPY uwsgi.ini /app
COPY example.beancount /data

