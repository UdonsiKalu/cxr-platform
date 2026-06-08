FROM node:20-alpine
RUN apk add --no-cache curl
WORKDIR /app
COPY lab/graphql/package.json ./
RUN npm install --omit=dev
COPY lab/graphql/*.mjs ./
