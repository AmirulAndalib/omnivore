FROM node:22.12-alpine

# Run everything after as non-privileged user.
WORKDIR /app

COPY package.json .
COPY yarn.lock .
COPY tsconfig.json .
COPY .eslintrc .

COPY /packages/rule-handler/package.json ./packages/rule-handler/package.json

RUN yarn install --pure-lockfile --network-timeout=300000

ADD /packages/rule-handler ./packages/rule-handler
RUN yarn workspace @omnivore/rule-handler build

# After building, fetch the production dependencies
RUN rm -rf /app/packages/rule-handler/node_modules
RUN rm -rf /app/node_modules
RUN yarn install --pure-lockfile --production --network-timeout=300000


EXPOSE 8080

CMD ["yarn", "workspace", "@omnivore/rule-handler", "start"]

