# Note this docker file is meant for local testing
# and not for production.

FROM node:22.12-alpine as builder
ENV NODE_OPTIONS=--max-old-space-size=8192
ARG APP_ENV
ARG BASE_URL
ARG SERVER_BASE_URL
ARG HIGHLIGHTS_BASE_URL
ENV NEXT_PUBLIC_APP_ENV=$APP_ENV
ENV NEXT_PUBLIC_BASE_URL=$BASE_URL
ENV NEXT_PUBLIC_SERVER_BASE_URL=$SERVER_BASE_URL
ENV NEXT_PUBLIC_HIGHLIGHTS_BASE_URL=$HIGHLIGHTS_BASE_URL

RUN apk add g++ make python3 py3-setuptools

WORKDIR /app

COPY package.json .
COPY yarn.lock .
COPY tsconfig.json .
COPY .prettierrc .
COPY .eslintrc .

COPY /packages/web/package.json ./packages/web/package.json

RUN yarn install --pure-lockfile --network-timeout=300000
ADD /packages/web ./packages/web

# We want an empty next.config.js when running in docker
RUN echo "module.exports = {}" > ./packages/web/next.config.js
RUN yarn workspace @omnivore/web build


FROM node:22.12-alpine as runner
LABEL org.opencontainers.image.source="https://github.com/omnivore-app/omnivore"

ENV NODE_ENV production
ENV PORT=8080
ENV NEXT_TELEMETRY_DISABLED 1

WORKDIR /app

COPY --from=builder /app/packages/web/next.config.js /app/packages/web/next.config.js
COPY --from=builder /app/packages/web/public/ /app/packages/web/public/
COPY --from=builder /app/packages/web/.next/ /app/packages/web/.next/
COPY --from=builder /app/packages/web/package.json /app/packages/web/package.json
COPY --from=builder /app/packages/web/node_modules /app/packages/web/node_modules
COPY --from=builder /app/node_modules /app/node_modules
COPY --from=builder /app/package.json /app/package.json

EXPOSE 8080
CMD ["yarn", "workspace", "@omnivore/web", "start"]
