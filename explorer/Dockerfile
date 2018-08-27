FROM node:8-alpine

WORKDIR /

RUN apk add --no-cache git python make gcc g++ && \
    npm config set prefix '/root/.npm-global' && \
    npm config set registry 'https://registry.npm.taobao.org' && \
    git clone https://github.com/hyperledger/blockchain-explorer.git && \
    cd /blockchain-explorer;npm install && \
    cd /blockchain-explorer/app/test;npm i;npm run test && \
    cd /blockchain-explorer/client;npm i;npm test -- -u --coverage;npm run build && \
    npm cache clean --force && \
    rm -rf /root/.config /root/.npm && \
    apk del git python make gcc g++ && \
    apk --update add postgresql-client findutils && \
    rm -rf /var/cache/apk/*

WORKDIR /blockchain-explorer

EXPOSE 8080

CMD ["/bin/sh", "start.sh"]
