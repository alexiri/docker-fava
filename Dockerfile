FROM alexiri/scipy:3.8 as build_env

ENV BEANCOUNT_VERSION "2.3.3"
ENV FAVA_VERSION "v1.18"
ENV BUILDDEPS "libxml2-dev libxslt1-dev gcc musl-dev git nodejs npm make g++ liblapack-dev gfortran"
# Short python version.
ENV PV "3.8"

WORKDIR /root
RUN apt update \
        && apt install -y ${BUILDDEPS} \
        && pip install --upgrade pip \
        && npm install -g npm@latest \
        && python3 -mpip install importlib_metadata

RUN echo "Install Beancount & Fava" \
        && git clone --branch ${BEANCOUNT_VERSION} --depth 1 https://github.com/beancount/beancount.git \
        && (cd beancount && git log -l1) \
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
        && python3 -mpip install beancount_portfolio_allocation \
        && python3 -mpip install pip install https://github.com/xuhcc/beancount-cryptoassets/archive/master.zip \
        && python3 -mpip install fava-investor \
        #&& echo "strip .so files:" \
        #&& find /usr/local/lib/python${PV}/site-packages -name *.so -print0|xargs -0 strip -v \
        && echo "remove __pycache__ directories" \
        && find /usr/local/lib/python${PV} -name __pycache__ -exec rm -rf -v {} + \
        && find /usr/local/lib/python${PV} -name '*.dist-info' -exec rm -rf -v {} +


FROM tiangolo/uwsgi-nginx-flask:python3.8

ENV BEANCOUNT_INPUT_FILE "/data/example.beancount"
ENV PV "3.8"

RUN rm -f /app/*
VOLUME /data

RUN apt update \
       && apt install -y liblapack3 \
       && rm -rf /var/lib/apt/lists/*
COPY --from=build_env /usr/local/lib/python${PV}/site-packages /usr/local/lib/python${PV}/site-packages
COPY --from=build_env /usr/local/bin/fava /usr/local/bin
COPY --from=build_env /usr/local/bin/bean* /usr/local/bin/
ADD amortize_over.py /usr/local/lib/python${PV}/site-packages
RUN cp -r /usr/local/lib/python${PV}/site-packages/fava/static /app

COPY main.py /app
COPY uwsgi.ini /app
COPY example.beancount /data
