# syntax=docker/dockerfile:1
# Next.js dev server.
#
# The build context is the Next.js repo (docker-compose.yml points here via
# STACK_DIR). Dockerfile.dockerignore next to this file keeps the host's
# node_modules/ and .next/ out of the image. At runtime compose bind-mounts the
# repo over /usr/src/app and keeps node_modules in an anonymous volume, so the
# Linux dependencies installed here are what actually run.
FROM node:22-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci

COPY . .

EXPOSE 3000

CMD ["npm", "run", "dev"]
