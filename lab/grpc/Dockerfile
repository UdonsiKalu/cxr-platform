FROM node:20-alpine
WORKDIR /app
COPY lab/grpc/package.json ./
RUN npm install --omit=dev
COPY lab/grpc/*.mjs lab/grpc/*.proto ./
ENV GRPC_PORT=50051
EXPOSE 50051
CMD ["node", "server.mjs"]
